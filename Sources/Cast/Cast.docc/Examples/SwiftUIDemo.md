# SwiftUIDemo

SwiftUI app demonstrating cast/classify/extract with live-streaming Recipe fields.

## Source

Full source: [Examples/Sources/SwiftUIDemo/main.swift](https://github.com/jaylann/Cast/blob/main/Examples/Sources/SwiftUIDemo/main.swift)

```swift
// What this shows: SwiftUI app demonstrating cast/classify/extract with live-streaming Recipe fields.

#if os(macOS) || os(iOS)

    import Cast
    import Observation
    import SwiftUI

    // MARK: - Demo Models

    @Castable
    struct Recipe {
        @Description("Short, punchy title")
        var title: String = ""

        @MaxCount(8)
        var ingredients: [String] = []

        @CastRange(1 ... 60)
        var prepMinutes: Int = 0
    }

    enum Sentiment: String, CastEnum, CaseIterable {
        case positive, negative, neutral
    }

    @Castable
    struct InvoiceFields {
        @Description("Invoice number from the document")
        var invoiceNumber: String = ""

        @Description("Total amount in USD")
        var totalUSD: Double = 0
    }

    // MARK: - View Model

    enum DemoMode: String, CaseIterable, Identifiable {
        case cast = "Cast"
        case classify = "Classify"
        case extract = "Extract"

        var id: String {
            rawValue
        }
    }

    @MainActor
    @Observable
    final class DemoViewModel {
        var modelID: String = "mlx-community/Llama-3.2-3B-Instruct-4bit"
        var prompt: String = "Quick weeknight pasta in 20 minutes."
        var sourceText: String = """
        ACME Corp.
        Invoice Number: INV-7421
        Date: 2025-03-12
        Total Due: $1,250.00 USD
        """

        var mode: DemoMode = .cast

        var model: CastModel?
        var isLoading: Bool = false
        var isGenerating: Bool = false

        var partialRecipe: Recipe.PartiallyGenerated?
        var progress: Double = 0
        var classification: Sentiment?
        var extracted: InvoiceFields?
        var errorMessage: String?

        var generationTask: Task<Void, Never>?

        var canGenerate: Bool {
            model != nil && !isGenerating && !isLoading
        }

        func loadModel() {
            guard !isLoading else { return }
            isLoading = true
            errorMessage = nil
            let id = modelID
            Task { [weak self] in
                do {
                    let loaded = try await CastModel.load(id)
                    await MainActor.run {
                        guard let self else { return }
                        self.model = loaded
                        self.isLoading = false
                    }
                } catch {
                    await MainActor.run {
                        guard let self else { return }
                        self.errorMessage = "Load failed: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                }
            }
        }

        func generate() {
            guard let model, !isGenerating else { return }
            errorMessage = nil
            partialRecipe = nil
            classification = nil
            extracted = nil
            progress = 0
            isGenerating = true

            let mode = self.mode
            let prompt = self.prompt
            let sourceText = self.sourceText

            generationTask = Task { [weak self] in
                defer {
                    Task { @MainActor [weak self] in
                        self?.isGenerating = false
                    }
                }

                do {
                    switch mode {
                    case .cast:
                        for try await partial in model.castStream(prompt, as: Recipe.self) {
                            let snapshot = partial.value
                            let pct = partial.progress
                            await MainActor.run { [weak self] in
                                self?.partialRecipe = snapshot
                                self?.progress = pct
                            }
                        }
                    case .classify:
                        let result: Sentiment = try await model.classify(prompt)
                        await MainActor.run { [weak self] in
                            self?.classification = result
                        }
                    case .extract:
                        let fields: InvoiceFields = try await model.extract(
                            from: sourceText,
                            instruction: prompt
                        )
                        await MainActor.run { [weak self] in
                            self?.extracted = fields
                        }
                    }
                } catch {
                    await MainActor.run { [weak self] in
                        self?.errorMessage = error.localizedDescription
                    }
                }
            }
        }

        func cancel() {
            model?.abortInFlight()
            generationTask?.cancel()
        }
    }

    // MARK: - Views

    struct ContentView: View {
        @State private var vm = DemoViewModel()

        var body: some View {
            Form {
                Section("Model") {
                    HStack {
                        TextField("Model ID", text: $vm.modelID)
                            .textFieldStyle(.roundedBorder)
                            .disabled(vm.isLoading || vm.model != nil)
                        Button(vm.model == nil ? "Load" : "Loaded") {
                            vm.loadModel()
                        }
                        .disabled(vm.isLoading || vm.model != nil)
                        if vm.isLoading {
                            ProgressView().controlSize(.small)
                        }
                    }
                }

                Section("Mode") {
                    Picker("Mode", selection: $vm.mode) {
                        ForEach(DemoMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(vm.mode == .extract ? "Instruction" : "Prompt") {
                    TextField("Prompt", text: $vm.prompt, axis: .vertical)
                        .lineLimit(2 ... 5)
                        .textFieldStyle(.roundedBorder)
                }

                if vm.mode == .extract {
                    Section("Source Text") {
                        TextEditor(text: $vm.sourceText)
                            .font(.body.monospaced())
                            .frame(minHeight: 100)
                    }
                }

                Section("Run") {
                    HStack {
                        Button("Generate") { vm.generate() }
                            .disabled(!vm.canGenerate)
                        Button("Cancel") { vm.cancel() }
                            .disabled(!vm.isGenerating)
                        if vm.isGenerating {
                            ProgressView().controlSize(.small)
                        }
                    }
                }

                Section("Output") {
                    OutputView(vm: vm)
                }

                if let error = vm.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
            .padding()
            .frame(minWidth: 600, minHeight: 500)
        }
    }

    struct OutputView: View {
        let vm: DemoViewModel

        var body: some View {
            switch vm.mode {
            case .cast:
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: vm.progress)
                    LabeledContent("Title") {
                        Text(vm.partialRecipe?.title ?? "—")
                            .foregroundStyle(vm.partialRecipe?.title == nil ? .secondary : .primary)
                    }
                    LabeledContent("Prep Minutes") {
                        Text(vm.partialRecipe?.prepMinutes.map { "\($0) min" } ?? "—")
                            .foregroundStyle(vm.partialRecipe?.prepMinutes == nil ? .secondary : .primary)
                    }
                    LabeledContent("Ingredients") {
                        if let ingredients = vm.partialRecipe?.ingredients, !ingredients.isEmpty {
                            VStack(alignment: .trailing) {
                                ForEach(Array(ingredients.enumerated()), id: \.offset) { _, item in
                                    Text(item)
                                }
                            }
                        } else {
                            Text("—").foregroundStyle(.secondary)
                        }
                    }
                }
            case .classify:
                if let result = vm.classification {
                    LabeledContent("Sentiment", value: result.rawValue)
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            case .extract:
                if let fields = vm.extracted {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Invoice Number", value: fields.invoiceNumber)
                        LabeledContent("Total USD", value: String(format: "%.2f", fields.totalUSD))
                    }
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
        }
    }

    @main
    struct SwiftUIDemoApp: App {
        var body: some Scene {
            WindowGroup {
                ContentView()
            }
        }
    }

#else

    @main
    enum SwiftUIDemoApp {
        static func main() {
            print("SwiftUIDemo requires macOS or iOS")
        }
    }

#endif
```
