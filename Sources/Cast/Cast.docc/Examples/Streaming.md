# Streaming

progressive partial-result yields from castStream(); each
field appears as the model fills it in.

## Source

Full source: [Examples/Sources/Streaming/main.swift](https://github.com/jaylann/Cast/blob/main/Examples/Sources/Streaming/main.swift)

```swift
// What this shows: progressive partial-result yields from castStream(); each
// field appears as the model fills it in.

import Cast
import Foundation

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
