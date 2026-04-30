# Cancellation

the two cooperative-cancellation patterns available today,
before the first-class timeout API in #41 lands. Both surface as a truncated
generation rather than a thrown CancellationError, so handle CastError.

1. didGenerate as a hard token budget — return .stop once the budget is hit.
2. Task.cancel() on the wrapping task — the sampler's Task.isCancelled check
   flips didGenerate to .stop on the next token.

Both paths short-circuit token generation, so the model's partial output is
fed to the decoder. If the JSON didn't finish you get CastError.decodingFailed
carrying the partial rawOutput.

## Source

Full source: [Examples/Sources/Cancellation/main.swift](https://github.com/jaylann/Cast/blob/main/Examples/Sources/Cancellation/main.swift)

```swift
// What this shows: the two cooperative-cancellation patterns available today,
// before the first-class timeout API in #41 lands. Both surface as a truncated
// generation rather than a thrown CancellationError, so handle CastError.
//
// 1. didGenerate as a hard token budget — return .stop once the budget is hit.
// 2. Task.cancel() on the wrapping task — the sampler's Task.isCancelled check
//    flips didGenerate to .stop on the next token.
//
// Both paths short-circuit token generation, so the model's partial output is
// fed to the decoder. If the JSON didn't finish you get CastError.decodingFailed
// carrying the partial rawOutput.

import Cast
import Collections
import Foundation
import JSONSchema

@Castable
struct LongStory {
    var title: String = ""
    var paragraphs: [String] = []
}

@main
enum Cancellation {
    static func main() async throws {
        let model = try await CastModel.load("mlx-community/Llama-3.2-3B-Instruct-4bit")
        let prompt = "Write a long fantasy short story with at least 8 paragraphs."

        // Scenario 1: token budget via didGenerate.
        do {
            let story: LongStory = try await model.cast(prompt) { tokens in
                tokens > 50 ? .stop : .more
            }
            print("[budget] decoded after early stop:", story)
        } catch let CastError.decodingFailed(raw, error) {
            print("[budget] truncated, decoding failed:", error)
            print("[budget] partial output:", raw.prefix(120), "...")
        }

        // Scenario 2: external Task.cancel.
        let task = Task<LongStory, Error> { try await model.cast(prompt) }
        try await Task.sleep(for: .milliseconds(200))
        task.cancel()
        do {
            let story = try await task.value
            print("[cancel] decoded before cancel landed:", story)
        } catch let CastError.decodingFailed(raw, error) {
            print("[cancel] truncated, decoding failed:", error)
            print("[cancel] partial output:", raw.prefix(120), "...")
        } catch {
            print("[cancel] other error:", error)
        }
    }
}

// Note: this is a workaround until https://github.com/jaylann/Cast/issues/41
// ships a first-class timeout / cancellation API.
```
