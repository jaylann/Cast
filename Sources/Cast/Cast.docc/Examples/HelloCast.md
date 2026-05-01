# HelloCast

load a model, declare a @Castable struct, and decode a typed
value with a single cast(_:) call. The minimal first-touch example.

## Source

Full source: [Examples/Sources/HelloCast/main.swift](https://github.com/jaylann/Cast/blob/main/Examples/Sources/HelloCast/main.swift)

```swift
// What this shows: load a model, declare a @Castable struct, and decode a typed
// value with a single cast(_:) call. The minimal first-touch example.

import Cast
import Foundation

@Castable
struct Person {
    var name: String = ""
    var age: Int = 0
    var occupation: String = ""
}

@main
enum HelloCast {
    static func main() async throws {
        let model = try await CastModel.load("mlx-community/Llama-3.2-3B-Instruct-4bit")

        let person: Person = try await model.cast(
            "Marie Curie was a 66-year-old physicist and chemist."
        )

        print(person)
    }
}

// Sample output (manual run, will vary by model):
// Person(name: "Marie Curie", age: 66, occupation: "physicist and chemist")
```
