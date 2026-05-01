import Cast
import Observation
import SwiftUI

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
                    // Cancel in-flight generation when the app backgrounds
                    // so iOS doesn't kill us for holding the GPU.
                    loaded.enableBackgroundSafety()
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

struct ContentView: View {
    @State private var vm = DemoViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Model") {
                    TextField("Model ID", text: $vm.modelID)
                        .disabled(vm.isLoading || vm.model != nil)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    HStack {
                        Button(vm.model == nil ? "Load Model" : "Loaded") {
                            vm.loadModel()
                        }
                        .disabled(vm.isLoading || vm.model != nil)
                        Spacer()
                        if vm.isLoading {
                            ProgressView()
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
                }

                if vm.mode == .extract {
                    Section("Source Text") {
                        TextEditor(text: $vm.sourceText)
                            .font(.body.monospaced())
                            .frame(minHeight: 120)
                    }
                }

                Section("Run") {
                    HStack {
                        Button("Generate") { vm.generate() }
                            .buttonStyle(.borderedProminent)
                            .disabled(!vm.canGenerate)
                        Spacer()
                        Button("Cancel") { vm.cancel() }
                            .buttonStyle(.bordered)
                            .disabled(!vm.isGenerating)
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
            .navigationTitle("Cast Demo")
        }
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
                if let ingredients = vm.partialRecipe?.ingredients, !ingredients.isEmpty {
                    LabeledContent("Ingredients") {
                        VStack(alignment: .trailing) {
                            ForEach(Array(ingredients.enumerated()), id: \.offset) { _, item in
                                Text(item ?? "—")
                            }
                        }
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
