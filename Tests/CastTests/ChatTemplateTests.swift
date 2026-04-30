import Cast
import Collections
import Foundation
import JSONSchema
import Testing

// Verifies Cast's flat-string prompt + system handoff to MLXLMCommon's
// processor.prepare(input:) produces valid structured JSON across the five
// canonical model families. Each family has a distinct chat template
// (Qwen <|im_start|>, Llama <|begin_of_text|>, Mistral [INST], Phi <|user|>,
// Gemma <start_of_turn>); these tests exercise that delegation end-to-end.
//
// All tests are .requiresMetal-gated: they download a 4-bit MLX model and
// run a real generation. CI runners (virtualized macos-15) cannot load the
// metallib — see issue #75 and .claude/rules/release-workflow.md.

@Castable
private struct Greeting {
    var text: String = ""
}

private let chatTemplatePrompt = "Say hello as a JSON object with field 'text'."

private func runGreeting(family: String, modelId: String) async throws {
    do {
        let model = try await CastModel.load(modelId)
        let result: Greeting = try await model.cast(chatTemplatePrompt)
        #expect(!result.text.isEmpty, "\(family) (\(modelId)) returned empty text field")
        await model.unload()
    } catch {
        Issue.record(
            "Chat template verification failed for family \(family) (\(modelId)): \(error)"
        )
        throw error
    }
}

@Test(.requiresMetal) func qwenEmitsValidJSON() async throws {
    try await runGreeting(
        family: "Qwen",
        modelId: "mlx-community/Qwen2.5-1.5B-Instruct-4bit"
    )
}

@Test(.requiresMetal) func llamaEmitsValidJSON() async throws {
    try await runGreeting(
        family: "Llama",
        modelId: "mlx-community/Llama-3.2-1B-Instruct-4bit"
    )
}

@Test(.requiresMetal) func mistralEmitsValidJSON() async throws {
    try await runGreeting(
        family: "Mistral",
        modelId: "mlx-community/Mistral-7B-Instruct-v0.3-4bit"
    )
}

@Test(.requiresMetal) func phiEmitsValidJSON() async throws {
    try await runGreeting(
        family: "Phi",
        modelId: "mlx-community/Phi-3.5-mini-instruct-4bit"
    )
}

@Test(.requiresMetal) func gemmaEmitsValidJSON() async throws {
    try await runGreeting(
        family: "Gemma",
        modelId: "mlx-community/gemma-2-2b-it-4bit"
    )
}
