// What this shows: the same prompt routed through five different model
// families to demonstrate cross-family chat-template support. Cast hands a
// flat "(system)\n\n(prompt)" string to MLXLMCommon's processor.prepare,
// which applies each tokenizer's chat_template — Qwen <|im_start|>,
// Llama <|begin_of_text|>, Mistral [INST], Phi <|user|>, Gemma
// <start_of_turn>. No per-family code paths in Cast.

import Cast
import Collections
import Foundation
import JSONSchema

@Castable
struct Greeting {
    var text: String = ""
}

@main
enum ChatTemplates {
    static let families: [(modelId: String, family: String)] = [
        ("mlx-community/Qwen2.5-1.5B-Instruct-4bit", "Qwen"),
        ("mlx-community/Llama-3.2-1B-Instruct-4bit", "Llama"),
        ("mlx-community/Mistral-7B-Instruct-v0.3-4bit", "Mistral"),
        ("mlx-community/Phi-3.5-mini-instruct-4bit", "Phi"),
        ("mlx-community/gemma-2-2b-it-4bit", "Gemma")
    ]

    static func main() async throws {
        let prompt = "Say hello as a JSON object with field 'text'."
        var failures: [String] = []

        for entry in families {
            print("--- \(entry.family) (\(entry.modelId))")
            do {
                let model = try await CastModel.load(entry.modelId)
                defer { model.unload() }
                let greeting: Greeting = try await model.cast(prompt)
                print("\(entry.family): \(greeting)")
            } catch {
                print("\(entry.family) failed: \(error)")
                failures.append(entry.family)
            }
        }

        if !failures.isEmpty {
            print("Failed families: \(failures.joined(separator: ", "))")
            exit(1)
        }
    }
}

// Sample output (illustrative; varies per model + run):
// --- Qwen (mlx-community/Qwen2.5-1.5B-Instruct-4bit)
// Qwen: Greeting(text: "Hello!")
// --- Llama (mlx-community/Llama-3.2-1B-Instruct-4bit)
// Llama: Greeting(text: "Hi there.")
// ...
