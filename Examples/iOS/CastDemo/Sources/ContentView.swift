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
        // Task inherits MainActor isolation from the enclosing context,
        // so we can mutate state directly without an inner MainActor.run hop.
        Task { [weak self] in
            do {
                let loaded = try await CastModel.load(id)
                guard let self else { return }
                self.model = loaded
                self.isLoading = false
                // Cancel in-flight generation when the app backgrounds
                // so iOS doesn't kill us for holding the GPU.
                loaded.enableBackgroundSafety()
            } catch {
                guard let self else { return }
                self.errorMessage = "Load failed: \(error.localizedDescription)"
                self.isLoading = false
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
            // The enclosing Task inherits MainActor isolation, so defer runs
            // synchronously on MainActor — no extra hop, no UX race window
            // where a fast second tap sees stale isGenerating=true.
            defer { self?.isGenerating = false }

            do {
                switch mode {
                case .cast:
                    for try await partial in model.castStream(prompt, as: Recipe.self) {
                        self?.partialRecipe = partial.value
                        self?.progress = partial.progress
                    }
                case .classify:
                    let result: Sentiment = try await model.classify(prompt)
                    self?.classification = result
                case .extract:
                    let fields: InvoiceFields = try await model.extract(
                        from: sourceText,
                        instruction: prompt
                    )
                    self?.extracted = fields
                }
            } catch {
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    func cancel() {
        // castStream's continuation.onTermination already cancels the
        // underlying generation when the local Task is cancelled, so we
        // don't need to call abortInFlight() (which would also cancel
        // unrelated in-flight calls on the same model).
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
        // Tear down any in-flight generation if the user navigates away
        // — iOS background safety only fires on app-backgrounding, not
        // on view disappearance, and we don't want to keep holding the
        // GPU while writing into an unobserved view-model.
        .onDisappear { vm.cancel() }
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
                                Text(item)
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
