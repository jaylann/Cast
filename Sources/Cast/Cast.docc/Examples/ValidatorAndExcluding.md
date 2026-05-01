# ValidatorAndExcluding

two recently-shipped advanced features in one example.
  1. @Validator(transform) runs a pure post-decode transform on each field —
     useful for normalising case, trimming whitespace, or clamping numeric
     values so downstream code never sees out-of-range data.
  2. JSONSchema.excluding(fields:) returns a new schema with named keys
     removed from properties + required. Pair it with cast(_:schema:) when
     one prompt should populate only a subset of a struct's fields.

## Source

Full source: [Examples/Sources/ValidatorAndExcluding/main.swift](https://github.com/jaylann/Cast/blob/main/Examples/Sources/ValidatorAndExcluding/main.swift)

```swift
// What this shows: two recently-shipped advanced features in one example.
//   1. @Validator(transform) runs a pure post-decode transform on each field —
//      useful for normalising case, trimming whitespace, or clamping numeric
//      values so downstream code never sees out-of-range data.
//   2. JSONSchema.excluding(fields:) returns a new schema with named keys
//      removed from properties + required. Pair it with cast(_:schema:) when
//      one prompt should populate only a subset of a struct's fields.

import Cast
import Foundation

@Castable
struct Contact {
    @Validator({ $0.lowercased().trimmingCharacters(in: .whitespaces) })
    var email: String = ""
    @Validator({ max(0, min(120, $0)) })
    var age: Int = 0
    var fullName: String = ""
    var internalNotes: String = ""
}

@main
enum ValidatorAndExcluding {
    static func main() async throws {
        let model = try await CastModel.load("mlx-community/Llama-3.2-3B-Instruct-4bit")

        let baseSchema = try SchemaGenerator.schema(for: Contact.self)
        let publicSchema = baseSchema.excluding(fields: ["internalNotes"])

        let contact: Contact = try await model.cast(
            "Extract a contact card for 'Ada Lovelace, age 36, ADA@EXAMPLE.COM'.",
            schema: publicSchema
        )

        // email is lowercased + trimmed by the validator;
        // age is clamped into 0...120;
        // internalNotes was excluded from the schema, so the model never wrote it.
        print(contact)
    }
}

// Background:
//  - @Validator: https://github.com/jaylann/Cast/pull/56
//  - JSONSchema.excluding(fields:): see git log for "JSONSchema+Excluding".
```
