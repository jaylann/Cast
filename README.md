# Cast

Type-safe structured output from any local LLM on Apple Silicon. `Cast` runs on top of [MLX Swift](https://github.com/ml-explore/mlx-swift) and uses constrained decoding plus a Swift macro to guarantee the model returns JSON that decodes into the type you asked for.

Think `as?` for LLMs.

📚 **[API Documentation](https://jaylann.github.io/Cast/documentation/cast/)** — auto-generated from source via DocC.

> **Status: pre-1.0.** Phases 0–2 (foundation, schema/wrappers, `@Castable` macro, tokenizer caching, `prepare`, `classify`) are shipped. Phase 3 in progress: timeouts/cancellation, JSON repair, iOS lifecycle, DocC are landed; streaming, benchmarks, per-model chat templates, and the demo app are still in flight — see [open issues](https://github.com/jaylann/Cast/issues).

---

## Install

Swift Package Manager. Add to your `Package.swift`:

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

Avoid base / completion checkpoints. The grammar will keep the JSON
syntactically valid, but content quality drops sharply without instruct
tuning. Per-model chat templates are tracked in [#37](https://github.com/jaylann/Cast/issues/37).

## Benchmarks

Coming with [#38](https://github.com/jaylann/Cast/issues/38) (CastBench harness)
and [#39](https://github.com/jaylann/Cast/issues/39) (overhead comparison).

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

// Raw JSON string with a generated schema
let json: String = try await model.castJSON("...", schema: Recipe.self)

// Decoded with an explicit JSONSchema (skip auto-schema generation)
let r2: Recipe = try await model.cast("...", as: Recipe.self, schema: someSchema)

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

Shipped in Phase 3:
- Truncated JSON detection / repair ([#40](https://github.com/jaylann/Cast/issues/40))
- Timeout & cancellation ([#41](https://github.com/jaylann/Cast/issues/41))
- Background/foreground GPU lifecycle, opt-in ([#42](https://github.com/jaylann/Cast/issues/42))
- DocC site ([#45](https://github.com/jaylann/Cast/issues/45))

Still open:
- Streaming `castStream() → AsyncSequence<PartialResult<T>>` ([#35](https://github.com/jaylann/Cast/issues/35))
- `extract()` extraction-optimized convenience ([#36](https://github.com/jaylann/Cast/issues/36))
- Per-model chat templates (Llama / Qwen / Mistral) ([#37](https://github.com/jaylann/Cast/issues/37))
- CastBench: tok/s, latency, grammar overhead ([#38](https://github.com/jaylann/Cast/issues/38), [#39](https://github.com/jaylann/Cast/issues/39))
- Example iOS app — blocked on streaming ([#44](https://github.com/jaylann/Cast/issues/44))

If you're migrating an existing project to `Cast` and hitting friction (Sendable/Decodable conformance, output quality, etc.), see `MIGRATION.md`.

## License

MIT. See `LICENSE`.
