# Getting Started

Install Cast, load a model, and decode your first typed value in five
minutes.

## Install

Cast is a Swift Package. Add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/jaylann/Cast.git", branch: "main")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [.product(name: "Cast", package: "Cast")]
    )
]
```

Requires macOS 14 / iOS 17 and Swift 6. Cast pulls in
[mlx-swift](https://github.com/ml-explore/mlx-swift) and
[mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) transitively;
no other setup is needed.

## Hello, Cast

The smallest useful program.

```swift
import Cast

@Castable
struct Person {
    var name: String = ""
    var age: Int = 0
}

let model = try await CastModel.load(
    "mlx-community/Llama-3.2-3B-Instruct-4bit"
)
let person: Person = try await model.cast(
    "Marie Curie was a 66-year-old physicist."
)
print(person)  // Person(name: "Marie Curie", age: 66)
```

Three things happened:

1. The `@Castable` macro generated a JSON schema from `Person` and a
   matching `Decodable` conformance.
2. ``CastModel/cast(_:as:system:config:didGenerate:)-2yyul`` constrained
   the model's sampler so every emitted token kept the JSON valid against
   that schema.
3. The resulting bytes were decoded into `Person`.

## Add constraints

Use the bundled property wrappers to tighten the schema:

```swift
@Castable
struct Recipe {
    @Description("Short, punchy title")
    var title: String = ""

    @MaxCount(8)
    var ingredients: [String] = []

    @CastRange(1...60)
    var prepMinutes: Int = 0
}
```

`@Description` and `@Examples` shape *content* (the model reads them as
guidance). `@CastRange`, `@MaxCount`, `@MinLength`, `@Pattern`, and friends
shape *form* — the grammar masks any token that would violate them.

## Configure the call

Pass a ``CastConfiguration`` for sampling, timeout, and JSON-repair knobs:

```swift
var config = CastConfiguration()
config.temperature = 0.0           // deterministic
config.maxTokens = 256
config.timeout = .seconds(10)      // throws CastError.timedOut on expiry

let r: Recipe = try await model.cast("Quick weeknight pasta", config: config)
```

## Where to go next

- <doc:Architecture> — the six layers Cast composes to do its job.
- <doc:HelloCast> through <doc:ErrorHandling> — runnable example targets
  in the repo's `Examples/` directory.
- ``CastModel/classify(_:as:system:config:didGenerate:)-3sl4w`` — the
  enum-classification fast-path.
- ``CastModel/enableBackgroundSafety()`` — opt in on iOS to avoid Metal
  GPU termination on background.
