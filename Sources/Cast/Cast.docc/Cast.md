# ``Cast``

Type-safe structured output from any local LLM on Apple Silicon.

## Overview

Cast is `as?` for LLMs. Annotate a Swift type with `@Castable`, hand it to a
``CastModel``, and get a typed value back — guaranteed to parse, guaranteed to
match the schema, no JSON repair, no retries.

```swift
import Cast

@Castable
struct Recipe {
    @Description("Short, punchy title")
    var title: String = ""

    @MaxCount(8)
    var ingredients: [String] = []

    @CastRange(1...60)
    var prepMinutes: Int = 0
}

let model = try await CastModel.load("mlx-community/Llama-3.2-3B-Instruct-4bit")
let recipe: Recipe = try await model.cast("Write me a quick weeknight pasta recipe.")
```

Under the hood, the `@Castable` macro generates a JSON schema from your struct
plus its property-wrapper annotations, and a custom `LogitsProcessor` masks
invalid tokens during decoding — so the model can only emit JSON that matches.

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:Architecture>

### Examples

- <doc:HelloCast>
- <doc:Classify>
- <doc:GenerationModes>
- <doc:NestedTypes>
- <doc:PropertyWrappersTour>
- <doc:ValidatorAndExcluding>
- <doc:PrepareWarmup>
- <doc:Cancellation>
- <doc:CallerManagedLoading>
- <doc:ErrorHandling>
- <doc:ChatTemplates>
- <doc:Smoketest>

### Essentials

- ``CastModel``
- ``CastConfiguration``
- ``CastError``
- ``JSONRepair``

### Property Wrappers

- ``Description``
- ``Examples``
- ``MaxLength``
- ``MinLength``
- ``CastRange``
- ``MaxCount``
- ``MinCount``
- ``Count``
- ``Pattern``
- ``Precision``
- ``OneOf``
- ``Nullable``
- ``DefaultValue``
- ``Validator``

### Enums in Schemas

- ``CastEnum``
