# Streaming

Watch fields fill in as the model writes them.

`castStream(_:as:system:config:)` returns an `AsyncThrowingStream` of
``PartialResult`` values. Each yield carries:

- `value` — a `T.PartiallyGenerated` snapshot (all-Optional mirror of `T`)
  decoded from the in-flight buffer once it can be repaired into valid JSON.
- `progress` — monotonic `0...1` ratio against `CastConfiguration.maxTokens`.
- `tokenCount` — running token count for the generation.

The terminal yield always carries a fully-decoded value (validated against
`T`'s required fields, not just the Optional mirror), matching the contract
of `cast()`. The stream honors `Task.cancel()` (surfaced as
`CastError.cancelled`) and `CastConfiguration.timeout`. Buffering is
`bufferingNewest(1)` — slow consumers see only the latest snapshot, never an
unbounded backlog.

## Source

Full source: [Examples/Sources/Streaming/main.swift](https://github.com/jaylann/Cast/blob/main/Examples/Sources/Streaming/main.swift)

```swift
import Cast
import Collections
import Foundation
import JSONSchema

@Castable
struct Recipe {
    var title: String = ""
    var prepMinutes: Int = 0
    var ingredients: [String] = []
}

@main
enum Streaming {
    static func main() async throws {
        let model = try await CastModel.load("mlx-community/Llama-3.2-3B-Instruct-4bit")
        let prompt = "Quick weeknight pasta in 20 minutes."

        for try await partial in model.castStream(prompt, as: Recipe.self) {
            let pct = Int((partial.progress * 100).rounded())
            print("[\(pct)% — \(partial.tokenCount) tokens]")
            if let title = partial.value.title { print("  title: \(title)") }
            if let minutes = partial.value.prepMinutes { print("  prepMinutes: \(minutes)") }
            if let ingredients = partial.value.ingredients {
                print("  ingredients: \(ingredients)")
            }
        }
    }
}
```
