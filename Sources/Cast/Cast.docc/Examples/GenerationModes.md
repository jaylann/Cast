# GenerationModes

the four generation surfaces side-by-side, same prompt,
same struct. Auto-schema vs. explicit JSONSchema, and decoded value vs. raw
JSON string.

## Source

Full source: [Examples/Sources/GenerationModes/main.swift](https://github.com/jaylann/Cast/blob/main/Examples/Sources/GenerationModes/main.swift)

```swift
// What this shows: the four generation surfaces side-by-side, same prompt,
// same struct. Auto-schema vs. explicit JSONSchema, and decoded value vs. raw
// JSON string.

import Cast
import Collections
import Foundation
import JSONSchema

@Castable
struct BookSummary {
    var title: String = ""
    var author: String = ""
    var year: Int = 0
}

@main
enum GenerationModes {
    static func main() async throws {
        let model = try await CastModel.load("mlx-community/Llama-3.2-3B-Instruct-4bit")
        let prompt = "Summarize the novel '1984' by George Orwell, published in 1949."

        let s1: BookSummary = try await model.cast(prompt)
        print("[1] cast<T> auto-schema:", s1)

        let s2 = try await model.castJSON(prompt, schema: BookSummary.self)
        print("[2] castJSON<T> auto-schema:", s2)

        let schema = try SchemaGenerator.schema(for: BookSummary.self)
        let s3: BookSummary = try await model.cast(prompt, schema: schema)
        print("[3] cast<T> explicit schema:", s3)

        let s4 = try await model.castJSON(prompt, schema: schema)
        print("[4] castJSON explicit schema:", s4)
    }
}

// When to pick which:
// [1] cast<T>:               default, decoded result, schema generated for you.
// [2] castJSON<T>:           same prompt path, you want the raw JSON for logging.
// [3] cast<T>(schema:):      reused/edited schema (e.g. from .excluding(fields:)).
// [4] castJSON(schema:):     full control on both schema and downstream parsing.
```
