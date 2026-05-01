# Cast

[![Tests](https://img.shields.io/github/actions/workflow/status/jaylann/Cast/test.yml?branch=stage&label=tests&logo=github)](https://github.com/jaylann/Cast/actions/workflows/test.yml)
[![Swift 6](https://img.shields.io/badge/swift-6.0-orange?logo=swift)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-macOS%2014%20%7C%20iOS%2017-lightgrey)](#install)
[![SwiftPM](https://img.shields.io/badge/SwiftPM-compatible-brightgreen)](#install)
[![DocC](https://img.shields.io/badge/docs-DocC-blue)](https://jaylann.github.io/Cast/documentation/cast/)
[![License](https://img.shields.io/github/license/jaylann/Cast)](LICENSE)

Type-safe structured output from any local LLM on Apple Silicon. `Cast` runs on top of [MLX Swift](https://github.com/ml-explore/mlx-swift) and uses constrained decoding plus a Swift macro to guarantee the model returns JSON that decodes into the type you asked for.

Think `as?` for LLMs.

📚 **[API Documentation](https://jaylann.github.io/Cast/documentation/cast/)** — auto-generated from source via DocC.

> **Status: pre-1.0.** Public API surface (`cast`, `castStream`, `extract`, `classify`, `prepare`, lifecycle, timeouts, JSON repair, `CastBench`, 5-family chat templates, DocC) is stable and tested. See the [open issues](https://github.com/jaylann/Cast/issues) for in-flight work.

**Jump to:** [Install](#install) · [Quickstart](#quickstart) · [Comparison](#how-cast-compares) · [Models](#recommended-models) · [Benchmarks](#benchmarks) · [Generation modes](#generation-modes) · [Configuration](#configuration) · [Roadmap](#roadmap)

---

## Install

Swift Package Manager. Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/jaylann/Cast.git", from: "0.1.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [.product(name: "Cast", package: "Cast")]
    )
]
```

Requires macOS 14 / iOS 17 and Swift 6.

## Quickstart

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

let recipe: Recipe = try await model.cast(
    "Write me a quick weeknight pasta recipe."
)

print(recipe.title)         // e.g. "15-Minute Garlic Butter Pasta"
print(recipe.ingredients)   // ["spaghetti", "butter", ...]
print(recipe.prepMinutes)   // 15
```

The `@Castable` macro generates a JSON schema from your struct (and the property-wrapper annotations), `cast()` constrains the LLM's output to that schema during decoding, and the result is decoded into your type. If the LLM tries to produce invalid JSON, the sampler masks the bad tokens before they're emitted — so decoding succeeds.

## How Cast compares

| | Cast | Apple `@Generable` (FoundationModels) | `outlines` (Python) | Prompting |
|---|---|---|---|---|
| Type-safety | ✅ Decoded into your Swift type | ✅ | ✅ | ❌ Hand-parse strings |
| Runs offline / on-device | ✅ Apple Silicon | ✅ Apple Silicon | ❌ Server-side | Depends |
| Works with any MLX model | ✅ | ❌ Apple Intelligence only | n/a | n/a |
| Compile-time grammar | ✅ Swift macro | ❌ Runtime | ❌ Runtime | n/a |
| Constraints (range, count, regex) | ✅ Property wrappers | Limited | ✅ | ❌ |
| Constrained sampling overhead | Single-digit % vs unconstrained | n/a (closed) | Similar | n/a |
| Min platform | macOS 14 / iOS 17 | macOS 26 / iOS 26 | Linux+CUDA | Anywhere |

The boundary is roughly: pick `@Generable` when you only ship to iOS 26+ and
are happy with Apple Intelligence; pick Cast when you want to choose your
own MLX model, target older OSes, or you need property-wrapper constraints.

## Recommended models

These mlx-community 4-bit instruct checkpoints are known to behave well
with Cast's grammar-constrained decoding. The first one is a good default.

| Model | When to use |
|---|---|
| `mlx-community/Llama-3.2-3B-Instruct-4bit` | Default. Small (≈2 GB), fast, decent quality. |
| `mlx-community/Qwen2.5-7B-Instruct-4bit` | Better quality on extraction / reasoning. ~5 GB. |
| `mlx-community/Mistral-7B-Instruct-v0.3-4bit` | Strong instruction-following alternative. ~5 GB. |

Avoid base / completion checkpoints — the grammar will keep the JSON
syntactically valid, but content quality drops sharply without instruct
tuning. Llama-3.2, Qwen-2.5, Mistral-v0.3, Phi-3.5, and Gemma-2 chat
templates are exercised in `Tests/CastTests/ChatTemplateTests.swift`.

## Benchmarks

Cast ships a built-in benchmarking utility, `CastBench`, for measuring tok/s,
latency, grammar-masking overhead, and (optionally) constrained-vs-unconstrained
validity rates on your own prompts and types.

```swift
let bench = CastBench(model)
let result = try await bench.run(type: Person.self, prompt: "...", iterations: 5)
print(result.formatted(as: .markdown))
```

See `Sources/Cast/Bench/CastBench.swift` for the API and output formats. Full
reference is published in the [Cast DocC site](https://jaylann.github.io/Cast/documentation/cast)
under *Examples → CastBench*.

## What you can put in a `@Castable` type

- **Stored properties only**, structs only (classes / actors / protocols are not supported by the macro).
- All stored properties must be `Decodable & Sendable`. The macro synthesizes `Decodable`; `Sendable` comes for free if every member is `Sendable`.
- Nested types must also be `@Castable` (or otherwise `Decodable`).
- Raw enums need `CastEnum` (see below).

### Property wrappers

| Wrapper | Applies to | Effect on schema |
|---|---|---|
| `@Description("...")` | any | `description` text — model uses it as guidance |
| `@Examples("a", "b")` | any | `examples` — soft hint, model uses it as guidance |
| `@MaxLength(n)` / `@MinLength(n)` | `String` | string length bounds |
| `@CastRange(lo...hi)` | `Int`, `Double`, `Float` | numeric range |
| `@MaxCount(n)` / `@MinCount(n)` / `@Count(n)` | `[T]` | array size bounds |
| `@Pattern("regex")` | `String` | regex constraint |
| `@Precision(n)` | `Double`, `Float` | max decimal places |
| `@OneOf(["A", "B"])` | `String` | enum-style allowed values |
| `@Nullable` | any | allows JSON `null` even when the type isn't optional |
| `@DefaultValue(...)` | any | default if the field is missing in output |
| `@Validator { x in ... }` | any | post-decode transform |

> **Gotcha:** annotations are read at *schema-generation* time. After JSON decode, the wrapper's stored constraint is reset to a zero value. If you need the constraint at runtime, store it yourself. See `MIGRATION.md`.

### Enums

```swift
import Cast

enum Sentiment: String, CastEnum {
    case positive, negative, neutral
}

let s: Sentiment = try await model.classify("Best burrito in town.")
```

`classify` is optimized for this case — it hard-caps `maxTokens ≤ 10` and `temperature = 0.0`.

## Generation modes

```swift
// Decoded into your type (recommended)
let r: Recipe = try await model.cast("...")

// Stream partial snapshots as the model fills in fields
for try await partial in model.castStream("...", as: Recipe.self) {
    print(partial.value.title ?? "(generating...)")
}

// Extract structured fields out of unstructured text
let r2: Recipe = try await model.extract(
    from: "...long article...",
    as: Recipe.self,
    instruction: "Extract the recipe."
)

// Raw JSON string with a generated schema
let json: String = try await model.castJSON("...", schema: Recipe.self)

// Decoded with an explicit JSONSchema (skip auto-schema generation)
let r3: Recipe = try await model.cast("...", as: Recipe.self, schema: someSchema)

// Raw JSON with an explicit schema
let json2: String = try await model.castJSON("...", schema: someSchema)

// Enum classification
let label: Sentiment = try await model.classify("...")
```

### Pre-warming

Each `(model, type)` pair compiles its grammar on first use. To pay that cost at startup:

```swift
try await model.prepare(Recipe.self, Sentiment.self)
```

### Token budget

To stop early on a token count (cheaper than a wall-clock deadline), use
`didGenerate`:

```swift
let r: Recipe = try await model.cast(
    "...",
    didGenerate: { tokens in
        tokens > 200 ? .stop : .more
    }
)
```

The closure receives cumulative token count after each step and returns
`.stop` to end generation early.

## Configuration

```swift
var config = CastConfiguration()
config.maxTokens = 512
config.temperature = 0.0       // deterministic
config.topP = 0.95
config.timeout = .seconds(10)  // CastError.timedOut on deadline
config.repairTruncatedJSON = true  // default; auto-close unfinished JSON tails

let r: Recipe = try await model.cast("...", config: config)
```

### Timeouts and cancellation

```swift
// Wall-clock deadline.
var c = CastConfiguration()
c.timeout = .seconds(10)
do {
    let r: Recipe = try await model.cast("...", config: c)
} catch let CastError.timedOut(partial) {
    print("hit deadline; partial:", partial as Any)
}

// External cancel.
let task = Task<Recipe, Error> { try await model.cast("...") }
task.cancel()
do {
    _ = try await task.value
} catch let CastError.cancelled(partial) {
    print("cancelled; partial:", partial as Any)
}
```

### iOS background safety (opt-in)

```swift
let model = try await CastModel.load(...)
model.enableBackgroundSafety()
```

When the app enters background, every in-flight `cast()` is cancelled (each
throws `CastError.cancelled`) and the GPU is synchronized — without this,
iOS will SIGKILL Metal users that hold the GPU while backgrounded. On
memory warnings the GPU cache is freed; running work is not cancelled.
Call `model.abortInFlight()` from a "Stop" button to cancel manually.

## Caller-managed model loading

If you already manage `ModelContainer` lifetime (e.g., shared across components), wrap it instead of calling `load`:

```swift
let model = CastModel(wrapping: existingContainer, configuration: existingConfig)
```

## Roadmap

Open work:
- Example iOS app with SwiftUI + streaming fields ([#44](https://github.com/jaylann/Cast/issues/44))

If you're migrating an existing project to `Cast` and hitting friction
(Sendable/Decodable conformance, output quality, etc.), see `MIGRATION.md`.

## Contributing

Issues and PRs welcome. PRs target `stage` (the default branch); `main` is
release-only. See `CONTRIBUTING.md` for label conventions and the release
workflow.

## License

Apache-2.0. See `LICENSE` and `NOTICE`.
