# NestedTypes

composing @Castable structs. An Article holds an Author and
an array of Sections — two levels of nesting plus a nested array. The schema
is generated recursively and additionalProperties:false stops the model from
inventing extra keys at any level.

## Source

Full source: [Examples/Sources/NestedTypes/main.swift](https://github.com/jaylann/Cast/blob/main/Examples/Sources/NestedTypes/main.swift)

```swift
// What this shows: composing @Castable structs. An Article holds an Author and
// an array of Sections — two levels of nesting plus a nested array. The schema
// is generated recursively and additionalProperties:false stops the model from
// inventing extra keys at any level.

import Cast
import Collections
import Foundation
import JSONSchema

@Castable
struct Author {
    var name: String = ""
    var affiliation: String = ""
}

@Castable
struct Section {
    var heading: String = ""
    var body: String = ""
}

@Castable
struct Article {
    var title: String = ""
    var author: Author = .init()
    var sections: [Section] = []
    var tags: [String] = []
    @Nullable var subtitle: String?
}

@main
enum NestedTypes {
    static func main() async throws {
        let model = try await CastModel.load("mlx-community/Llama-3.2-3B-Instruct-4bit")
        let article: Article = try await model.cast(
            "Write a short two-section article about photosynthesis."
        )
        print(article)
    }
}

// Sample output (illustrative):
// Article(title: "Photosynthesis 101",
//         author: Author(name: "Dr. Lin", affiliation: "MIT"),
//         sections: [Section(heading: "Light Reactions", body: "..."),
//                    Section(heading: "Calvin Cycle", body: "...")],
//         tags: ["biology", "plants"], subtitle: nil)
```
