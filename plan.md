# Cast — Full Project Plan

**Type-safe structured output from any local LLM on Apple Silicon.**

_`as?` for LLMs. Constrained decoding for MLX Swift._

Repository: `github.com/jaylann/Cast`
License: MIT
Author: Justin Lanfermann

---

## 1. The Problem

iOS developers building on-device AI features with MLX Swift have no way to guarantee structured output from language models. The current workflow is broken:

1. Prompt the model to output JSON
2. Hope it complies
3. Try to parse the raw string
4. Handle the 10–30% failure rate where the model outputs malformed JSON, extra commentary, or hallucinated fields
5. Write retry logic, fallback parsing, and error handling that doubles the codebase

Apple's Foundation Models framework introduced `@Generable` macros for guided generation at WWDC 2025, but these only work with Apple's own on-device models. Developers using any of the thousands of open models on HuggingFace via MLX Swift — Llama, Qwen, Mistral, Phi, Gemma — have zero structured generation support.

In the Python ecosystem, this problem is solved by Outlines, Instructor, XGrammar, and llm-structured-output. In Swift, nothing exists. An open issue (#221) on Apple's mlx-swift-examples repo has been requesting this since March 2025 with no solution shipped.

The on-device AI market is valued at $17.6B in 2025 and projected to reach $115.7B by 2033 at 26.6% CAGR. Apple is investing heavily in on-device ML (Foundation Models, MLX framework, Neural Engine optimizations). The tooling layer between "raw MLX Swift" and "production iOS app" is empty. Cast fills that gap.

---

## 2. The Solution

Cast is a Swift package that enables constrained decoding from any MLX-compatible language model. Developers define output types as normal Swift structs with annotations, and Cast guarantees that every model generation produces a valid instance of that type — 100% of the time, by construction.

```swift
import Cast

@Castable
struct MovieReview: Codable {
    @Description("The movie title exactly as written")
    @MaxLength(100)
    var title: String

    @Description("Rating from 1-10")
    @Range(1...10)
    var rating: Int

    @MaxCount(5)
    var themes: [String]

    @Examples("Excellent pacing", "Weak third act")
    @MaxLength(200)
    var summary: String

    var sentiment: Sentiment
}

enum Sentiment: String, Codable, CastEnum {
    case positive, negative, mixed
}

let model = try await CastModel("mlx-community/Qwen3-1.5B-4bit")
let review: MovieReview = try await model.cast("Review the movie Inception")
```

No prompt engineering. No JSON parsing. No error handling for malformed output. The Swift type system defines what the model can produce.

---

## 3. Feature Specification

### 3.1 The `@Castable` Macro

The central feature. A Swift macro that inspects a `Codable` struct at compile time, reads all property wrapper annotations, and generates a static grammar representation used by the constrained decoding engine at runtime.

**What the macro generates at compile time (stored as a static constant on the type):**

- JSON Schema derived from the struct's shape and all nested types
- Grammar rules for each field (string, number, array, object productions)
- Enum field token allow-lists (pre-computed valid token sequences per case)
- Constraint metadata from property wrappers (ranges, lengths, counts)
- Validation logic that surfaces compile-time errors for invalid annotations

**What remains at runtime:**

- Tokenizer binding: mapping grammar tokens to a specific model's vocabulary IDs (cached after first use per model)
- Logit masking during token sampling
- KV cache management

This split means the expensive grammar construction happens during compilation, not on every inference call. First inference with a new model pays a one-time tokenizer binding cost (typically <100ms), then subsequent calls use cached mappings.

### 3.2 Property Wrapper Annotations

Annotations control constrained decoding at the field level. They compile to grammar rules enforced during token sampling — the model physically cannot produce output that violates them.

#### String Constraints

```swift
@Castable
struct UserProfile: Codable {
    @MinLength(1)
    @MaxLength(50)
    var name: String

    @Pattern(#"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#)
    var email: String

    @OneOf(["USD", "EUR", "GBP", "JPY", "CHF"])
    var preferredCurrency: String
}
```

| Annotation        | Behavior                       | Enforcement                                                            |
| ----------------- | ------------------------------ | ---------------------------------------------------------------------- |
| `@MaxLength(n)`   | Limits string to n characters  | Forces closing quote token once limit reached                          |
| `@MinLength(n)`   | Requires at least n characters | Blocks closing quote until minimum met                                 |
| `@Pattern(regex)` | Constrains to regex match      | Regex compiled to FSM at build time; only FSM-advancing tokens allowed |
| `@OneOf([...])`   | Restricts to fixed value set   | Pre-computes token sequences for each value; masks all others          |

#### Numeric Constraints

```swift
@Castable
struct SensorReading: Codable {
    @Range(0...100)
    var confidence: Int

    @Range(0.0...1.0)
    var probability: Double

    @Precision(2)
    var temperature: Double
}
```

| Annotation            | Behavior              | Enforcement                                                  |
| --------------------- | --------------------- | ------------------------------------------------------------ |
| `@Range(closedRange)` | Constrains to range   | Masks digit tokens to only allow valid numbers within bounds |
| `@Precision(n)`       | Limits decimal places | Constrains digit count after decimal point                   |

#### Array Constraints

```swift
@Castable
struct SearchResults: Codable {
    @MinCount(1)
    @MaxCount(10)
    var results: [SearchResult]

    @Count(3)
    var topPicks: [String]
}
```

| Annotation     | Behavior                     | Enforcement                              |
| -------------- | ---------------------------- | ---------------------------------------- |
| `@MaxCount(n)` | Limits array to n elements   | Forces closing bracket after n elements  |
| `@MinCount(n)` | Requires at least n elements | Blocks closing bracket until minimum met |
| `@Count(n)`    | Exact element count          | Combines min and max                     |

#### Semantic Guidance (Soft Constraints)

```swift
@Castable
struct ProductReview: Codable {
    @Description("The product name exactly as it appears on the listing")
    var productName: String

    @Examples("Great value for money", "Disappointing build quality")
    var summary: String
}
```

| Annotation          | Behavior                    | Enforcement                                         |
| ------------------- | --------------------------- | --------------------------------------------------- |
| `@Description(...)` | Guides model understanding  | Injected into system prompt (soft, not token-level) |
| `@Examples(...)`    | Few-shot examples for field | Injected into prompt context to bias output style   |

#### Nullability and Defaults

```swift
@Castable
struct ContactInfo: Codable {
    var name: String

    @Nullable
    var phoneNumber: String?

    @DefaultValue("Unknown")
    var company: String
}
```

| Annotation           | Behavior                                 | Enforcement                              |
| -------------------- | ---------------------------------------- | ---------------------------------------- |
| `@Nullable`          | Allows explicit null generation          | Adds null as valid production in grammar |
| `@DefaultValue(...)` | Substitutes value if model produces null | Applied post-generation                  |

### 3.3 Enum Support

Swift enums with `String` or `Int` raw values are first-class citizens. The grammar constrains output to only valid case names or values.

```swift
enum Priority: String, Codable, CastEnum {
    case low, medium, high, critical
}

enum StatusCode: Int, Codable, CastEnum {
    case ok = 200
    case notFound = 404
    case serverError = 500
}

@Castable
struct TicketClassification: Codable {
    var priority: Priority        // Only "low"/"medium"/"high"/"critical" allowed
    var suggestedStatus: StatusCode  // Only 200/404/500 allowed
}
```

At compile time, the macro pre-computes exact valid token sequences for each enum case. At runtime with a specific tokenizer, these map to concrete vocabulary IDs — the tightest possible constraint with zero wasted sampling.

### 3.4 Nested and Recursive Types

Cast handles arbitrarily complex nested type hierarchies. The macro recursively walks all nested types and generates a combined grammar where each nested struct becomes a sub-production.

```swift
@Castable
struct Article: Codable {
    var title: String
    var author: Author
    @MaxCount(20)
    var sections: [Section]
    var metadata: Metadata
}

struct Author: Codable {
    var name: String
    @Nullable var affiliation: String?
}

struct Section: Codable {
    var heading: String
    var body: String
    @MaxCount(5) var subsections: [Subsection]
}

struct Subsection: Codable {
    var heading: String
    var body: String
}

struct Metadata: Codable {
    var wordCount: Int
    @MaxCount(10) var tags: [String]
    var category: Category
}
```

### 3.5 Model Management

Cast wraps MLX Swift's model loading with convenience APIs.

```swift
// Pull and cache a model
let model = try await CastModel("mlx-community/Qwen3-1.5B-4bit")

// List cached models
let cached = CastModel.cached()

// Load with configuration
let model = try await CastModel(
    "mlx-community/Mistral-7B-Instruct-v0.3-4bit",
    config: .init(maxTokens: 2048, temperature: 0.7, topP: 0.9)
)

// Pre-warm grammar cache for types you'll use
try await model.prepare(MovieReview.self, Recipe.self, Invoice.self)
```

### 3.6 Generation Modes

#### Typed Generation (Primary)

```swift
let review: MovieReview = try await model.cast(
    "Review the movie Inception",
    config: .init(temperature: 0.7)
)
```

#### Streaming Generation

```swift
for try await partial in model.castStream("Analyze this document", as: Analysis.self) {
    // Fields populate one-by-one as the model generates them
    print(partial.title ?? "generating title...")
    print(partial.progress)  // 0.0 to 1.0
}
```

`PartialResult<T>` exposes each field as optional, populated in the order the JSON is generated. Enables real-time UI updates in SwiftUI as the model works.

#### Classification (Optimized)

```swift
let sentiment: Sentiment = try await model.classify(
    "This product is terrible and broke after one day"
)
```

Optimized path that only samples from enum case tokens. Typically 1–3 tokens total, making classification nearly instant. Useful for sentiment analysis, intent routing, content moderation.

#### Extraction

```swift
let invoice: InvoiceData = try await model.extract(
    from: pdfTextContent,
    as: InvoiceData.self,
    instruction: "Extract all invoice fields from this document"
)
```

Convenience wrapper that constructs an extraction-optimized prompt, placing the source content in a clearly delimited context block.

#### JSON Generation

```swift
let json: String = try await model.castJSON(
    "Extract the address",
    schema: Address.self
)
// Guaranteed valid JSON matching the Address schema, returned as raw string
```

For cases where developers want the raw JSON rather than a decoded struct.

### 3.7 Prompt Construction

Cast automatically constructs optimal prompts combining the user's instruction with schema context. Customizable at every level.

```swift
// Automatic (default) — Cast builds the prompt from schema + annotations
let result: Recipe = try await model.cast("Give me a pasta recipe")

// Custom system prompt
let result: Recipe = try await model.cast(
    "Give me a pasta recipe",
    system: "You are a professional Italian chef."
)

// Full prompt control
let result: Recipe = try await model.cast(
    prompt: ChatMessages([
        .system("You are a chef."),
        .user("Here's a recipe description: \(text)"),
        .user("Extract the recipe.")
    ]),
    as: Recipe.self
)
```

The auto-constructed prompt injects `@Description` and `@Examples` annotations as field-level guidance within the system prompt.

### 3.8 Compile-Time Safety

The `@Castable` macro catches annotation errors before runtime.

```swift
@Castable
struct BadExample: Codable {
    @Range(1...10)   var name: String    // ❌ Compile error: @Range cannot apply to String
    @MaxLength(50)   var count: Int      // ❌ Compile error: @MaxLength cannot apply to Int
    @MaxCount(5)     var title: String   // ❌ Compile error: @MaxCount requires Array type
    @Range(10...5)   var score: Int      // ❌ Compile error: lower bound exceeds upper bound
    @MinLength(100) @MaxLength(50)
                     var bio: String     // ❌ Compile error: MinLength exceeds MaxLength
}
```

### 3.9 Tokenizer-Aware Caching

Grammar-to-tokenizer mapping is the most expensive runtime operation. Cast caches it aggressively.

```swift
// First call: builds tokenizer mapping (~50-100ms)
let review1: MovieReview = try await model.cast("Review Inception")

// Second call: cached (<1ms overhead)
let review2: MovieReview = try await model.cast("Review Interstellar")

// Pre-warm at app launch
try await model.prepare(MovieReview.self, Recipe.self, Invoice.self)
```

Cache keyed on `(tokenizer hash, Castable type identity)`. Persists for CastModel lifetime. `.prepare()` enables zero-overhead first inference.

### 3.10 Local Benchmarking

Built-in utilities for measuring structured generation performance locally.

```swift
let bench = try await CastBench(model)

let result = try await bench.run(
    type: MovieReview.self,
    prompt: "Review Inception",
    iterations: 10
)

print(result.tokensPerSecond)       // 45.2 tok/s
print(result.averageLatency)        // 1.23s
print(result.grammarOverheadMs)     // 2.1ms per token
print(result.validOutputRate)       // 1.0 (always 100% with Cast)
print(result.averageTokenCount)     // 156 tokens
```

Comparison mode measures the cost of constraints vs unconstrained generation:

```swift
let comparison = try await bench.compare(
    type: MovieReview.self,
    prompt: "Review Inception as JSON",
    iterations: 10
)
print(comparison.overheadPercent)          // 2.8% slower with constraints
print(comparison.unconstrainedValidRate)   // 0.73 (only 73% valid without Cast)
```

Outputs formatted as shareable tables, Markdown reports, and JSON for CI integration.

### 3.11 Supported Types

| Swift Type           | JSON Mapping             | Available Constraints                                       |
| -------------------- | ------------------------ | ----------------------------------------------------------- |
| `String`             | `"string"`               | MaxLength, MinLength, Pattern, OneOf, Description, Examples |
| `Int`                | `number` (integer)       | Range                                                       |
| `Double` / `Float`   | `number` (float)         | Range, Precision                                            |
| `Bool`               | `true` / `false`         | —                                                           |
| `Optional<T>`        | `T` or `null`            | Nullable, DefaultValue                                      |
| `[T]`                | `array`                  | MaxCount, MinCount, Count                                   |
| `Codable` struct     | `object`                 | Recursive annotation support                                |
| `String`-backed enum | `"string"` (constrained) | Auto-detected from cases                                    |
| `Int`-backed enum    | `number` (constrained)   | Auto-detected from cases                                    |

---

## 4. Architecture

```
┌──────────────────────────────────────────────────────────┐
│                     Developer API                         │
│   @Castable macro  ·  .cast()  ·  .classify()            │
│   Property wrappers  ·  CastModel  ·  CastBench          │
├──────────────────────────────────────────────────────────┤
│                    Prompt Engine                           │
│   Auto-constructs prompts from schema + annotations       │
│   Handles chat templates for different model families      │
├──────────────────────────────────────────────────────────┤
│             Grammar Compiler (build-time)                  │
│   Struct → JSON Schema → Grammar Rules → State Machine     │
│   Runs inside @Castable macro expansion                    │
├──────────────────────────────────────────────────────────┤
│           Tokenizer Linker (runtime, cached)               │
│   Grammar States × Vocabulary → Token Mask Tables          │
│   One-time per (model, type) pair, then cached             │
├──────────────────────────────────────────────────────────┤
│                Constrained Sampler                         │
│   Custom LogitsProcessor for MLX Swift's generate()        │
│   Reads grammar state → masks invalid tokens → samples     │
├──────────────────────────────────────────────────────────┤
│                  MLX Swift (Apple)                         │
│   Model loading  ·  Inference  ·  Token generation         │
└──────────────────────────────────────────────────────────┘
```

**Layer 1 — Developer API.** The only layer developers interact with. Macro, wrappers, annotations, generation methods.

**Layer 2 — Prompt Engine.** Takes user prompt + schema metadata (descriptions, examples) and constructs an optimal prompt. Handles chat template formatting per model family (Llama uses `<|begin_of_text|>`, Qwen uses `<|im_start|>`, etc.).

**Layer 3 — Grammar Compiler.** Runs at build time inside the Swift macro. Converts annotated struct into a deterministic grammar. Outputs a static constant on the type containing the pre-compiled state machine skeleton.

**Layer 4 — Tokenizer Linker.** Runs once per (model, type) pair at runtime. Maps grammar states to concrete token IDs from the model's tokenizer. Produces a lookup table: "in grammar state X, these token IDs are valid." Cached aggressively.

**Layer 5 — Constrained Sampler.** A custom `LogitsProcessor` that hooks into MLX Swift's generation loop. Before each token is sampled, reads current grammar state, looks up valid token mask, zeros out all invalid logits. Model samples only from valid continuations.

**Layer 6 — MLX Swift.** Apple's framework handles actual neural network inference. Cast doesn't modify or fork MLX Swift — it composes with it through the public sampling API.

---

## 5. Technical Implementation

### 5.1 Constrained Decoding Engine

The core technical challenge. The engine maintains a finite state machine that tracks the current position within the JSON structure being generated. At each token, it computes which tokens are valid next and masks everything else.

**Implementation approach for v1:** Port the direct-schema-steering approach from `llm-structured-output` (Python → Swift). This approach steers output using the JSON schema directly rather than converting to a formal grammar, enabling flexible constraint enforcement with low overhead. The codebase is small and focused.

**Future upgrade path:** Integrate XGrammar's C++ core via Swift's C interop for near-zero overhead constrained decoding. XGrammar is the fastest engine available and supports general context-free grammars beyond JSON.

### 5.2 Build-Time vs Runtime Split

The key architectural insight. Swift macros enable shifting grammar construction to compile time.

**Build time (macro expansion):**

- JSON Schema generation from struct shape
- Constraint extraction from property wrappers
- Grammar rule generation
- State machine structure (states and transitions)
- Enum field token allow-lists
- Annotation validation (type-checking constraints against field types)

**Runtime (tokenizer-dependent, cached after first use):**

- Mapping grammar tokens to model-specific vocabulary IDs
- Logit masking during sampling
- KV cache management

The state machine structure is static and model-independent. Only the final step — mapping abstract tokens like "the digit 7" to a specific vocabulary ID — requires knowledge of the model's tokenizer.

### 5.3 Phase 1 Strategy: Runtime Reflection First

Phase 1 uses `Mirror` (Swift runtime reflection) instead of macros for grammar generation. This gets a working product in 2–3 weeks without the complexity of macro development. The API stays the same — developers still write `@Castable` structs and call `.cast()` — but the grammar is built at runtime on first call rather than at compile time.

Phase 2 replaces the reflection path with macro-generated static grammars. Same API, better performance, compile-time safety. Developers don't change any code.

---

## 6. Implementation Roadmap

### Phase 1: Core Engine — Weeks 1–3

**Goal:** Working constrained JSON generation from any MLX model with basic Codable structs.

**Deliverables:**

- JSON Schema generation from Swift Codable using Mirror
- Constrained sampler as a LogitsProcessor for MLX Swift's generate()
- State machine tracking position within JSON (in object, in key, in string value, in number, etc.)
- Token masking for structural tokens (`{`, `}`, `[`, `]`, `:`, `,`, `"`)
- Type enforcement: strings, integers, floats, booleans, null, arrays, nested objects
- Enum support with pre-computed token sequences
- CastModel wrapper with HuggingFace download and caching
- Basic `.cast()` and `.castJSON()` methods
- Unit tests with 5+ model families (Qwen, Llama, Phi, Gemma, Mistral)
- README with quickstart example

**Milestone:** `model.cast(prompt, as: Type.self)` works reliably for basic Codable structs across multiple models.

### Phase 2: Annotations + Macro — Weeks 4–5

**Goal:** Property wrapper constraints and compile-time grammar generation.

**Deliverables:**

- Property wrappers: `@MaxLength`, `@MinLength`, `@Range`, `@MaxCount`, `@MinCount`, `@Description`, `@Examples`, `@OneOf`, `@Nullable`, `@DefaultValue`, `@Precision`, `@Count`
- `@Castable` Swift macro replacing Mirror-based reflection
- Compile-time validation of annotation combinations
- Compile-time errors for invalid annotations (wrong type, contradictory constraints)
- Tokenizer-aware caching system with `(tokenizer hash, type identity)` keys
- `.prepare()` pre-warming API
- `.classify()` optimized enum classification path
- Prompt engine with auto-construction from annotations

**Milestone:** Full annotation system with compile-time safety. Classification works in 1–3 tokens.

### Phase 3: DX, Streaming, Polish — Weeks 6–7

**Goal:** Production-ready v1.0 with streaming, benchmarking, and documentation.

**Deliverables:**

- Streaming generation with `PartialResult<T>` and AsyncSequence
- `.extract()` convenience method for document extraction
- Local benchmarking utilities (CastBench) with formatted output
- `@Pattern(regex)` support (regex → FSM compilation)
- Comprehensive documentation: README, API docs, migration guide from raw JSON parsing
- Example iOS app demonstrating on-device structured generation with SwiftUI
- Example showing streaming fields populating a UI in real-time
- Performance benchmarks published (overhead vs unconstrained generation)
- Swift Package Index listing
- Blog post: "I built an App Store app with on-device ML — here's the library I wish existed"

**Milestone:** v1.0 public release. Ready for Show HN launch.

### Phase 4: Post-Launch Iteration — Weeks 8–12

**Goal:** Community-driven improvements and Cast Bench Cloud MVP.

**Deliverables:**

- Community feedback integration (issues, PRs, feature requests)
- Vision model support (image + prompt → structured output)
- Batch generation
- Context-free grammar support for non-JSON formats
- XGrammar C++ integration for near-zero overhead (replacing v1 engine)
- Model-specific optimizations (chat templates, token quirks per family)
- Cast CLI tool for benchmarking from command line
- Cast Bench Cloud MVP (see Section 8)

### Phase 5: Ecosystem Expansion — Months 4–6

**Goal:** Cast becomes the standard structured generation tool for Swift.

**Deliverables:**

- Xcode Preview integration (live structured output preview while editing schemas)
- Swift Playground support
- Integration guides for popular iOS architectures (TCA, MVVM, SwiftUI)
- Fine-tuning guide: how to improve model quality for specific Cast schemas
- Curated model recommendations per task type
- Conference talk submissions (try! Swift, Swift Connection, NSSpain, iOSDevUK)
- Cast Bench Cloud full launch with pricing

---

## 7. Positioning and Differentiation

### vs. Apple Foundation Models `@Generable`

Apple's macros work only with Apple's own on-device models. Cast works with any MLX-compatible model from HuggingFace — thousands of models vs one family. Developers who need multilingual support, domain-specific models, or larger models than Apple provides have no choice but to use open models. Cast is their only option for structured output.

### vs. Outlines / Instructor (Python)

Python-only. No iOS developer will embed a Python runtime in their app. Cast is native Swift, compiles into the app binary, runs on-device with zero external dependencies beyond MLX Swift.

### vs. llama.cpp GBNF Grammars

Requires hand-writing grammars in a custom format that most developers have never seen. Cast auto-generates constraints from normal Swift types with standard property wrappers. Zero new syntax to learn.

### vs. Prompting the Model for JSON

Fails 10–30% of the time depending on model size and complexity. Requires parsing, validation, retry logic, error handling. Cast guarantees valid output by construction — 100% of the time. The type system is the schema.

### vs. Server-Side Structured Generation

Requires internet, adds latency, costs money per API call, sends data off-device. Cast runs entirely on-device with zero cloud dependency. For privacy-sensitive applications (healthcare, finance, legal), this is a requirement, not a preference.

---

## 8. Monetization: Cast Bench Cloud

### 8.1 The Problem It Solves

An iOS developer building with Cast needs to choose a model. Qwen 1.5B? Llama 3.2 3B? Phi-4 Mini? Each performs differently depending on three variables:

- **Device:** iPhone 15 (6GB RAM) vs iPhone 16 Pro (8GB) vs M4 MacBook (16GB+)
- **Schema complexity:** Simple 3-field classification vs 20-field nested extraction
- **Output quality:** A 1.5B model is fast but might put the vendor name in the customer field

Currently the developer downloads each model manually (4GB+ each), benchmarks on their one device, and eyeballs output quality. That's hours of work per model, and they only get data for their hardware.

### 8.2 The Product

Cast Bench Cloud lets developers upload their `@Castable` schema and test data, then benchmarks across a matrix of models and simulated devices — returning speed, memory, and quality metrics in minutes without downloading a single model.

**CLI interface:**

```bash
cast bench \
  --schema InvoiceData.swift \
  --test-data ./invoices/*.txt \
  --models qwen3-1.5b,llama-3.2-3b,phi-4-mini,gemma-3-4b,mistral-7b \
  --devices iphone15,iphone16pro,m4-macbook
```

**Report output:**

```
┌──────────────────────────────────────────────────────────────────┐
│  Cast Bench Report: InvoiceData                                  │
│  5 models × 3 devices × 50 test samples                         │
├───────────────────┬──────────┬──────────┬──────────┬─────────────┤
│ Model             │ iPhone15 │ iPhone16P│ M4 Mac   │ Quality     │
├───────────────────┼──────────┼──────────┼──────────┼─────────────┤
│ Qwen3-1.5B-4bit   │ 38 tok/s │ 52 tok/s │ 89 tok/s │ 72/100      │
│ Llama-3.2-3B-4bit │ 21 tok/s │ 34 tok/s │ 67 tok/s │ 88/100      │
│ Phi-4-mini-4bit   │ 29 tok/s │ 41 tok/s │ 74 tok/s │ 85/100      │
│ Gemma-3-4B-4bit   │ 15 tok/s │ 26 tok/s │ 58 tok/s │ 91/100      │
│ Mistral-7B-4bit   │  -- OOM  │ 12 tok/s │ 45 tok/s │ 93/100      │
├───────────────────┴──────────┴──────────┴──────────┴─────────────┤
│ Recommendation: Phi-4-mini for iPhone, Gemma-3 for Mac           │
│ Mistral-7B exceeds iPhone 15 memory (6.2GB required)             │
└──────────────────────────────────────────────────────────────────┘
```

### 8.3 Key Features

**Quality scoring with LLM-as-judge.** Not just speed — a larger model grades whether structured output is semantically correct. Cast guarantees syntactic validity, but can't guarantee the model understood the prompt. The quality score catches a 1.5B model putting vendor name in the customer field.

**Ground truth evaluation.** When developers upload test data with expected outputs (labeled examples), quality scoring becomes real accuracy measurement. "Phi-4-mini correctly extracted 47/50 invoice totals, Qwen3 got 43/50."

**Regression testing.** Saved test suites run automatically when new models drop on HuggingFace. Developers get notified: "Qwen 3.5 just released and scores 94% on your InvoiceData extraction, up from 88% on Qwen 3."

**Schema iteration feedback.** Developer changes their struct — adds a field, tweaks a `@Description`. Re-run against same test data instantly. "Adding @Description to the vendor field improved accuracy from 82% to 91% across all models."

**No model downloads required.** All models pre-loaded on cloud infrastructure. What takes an afternoon locally (downloading 40GB+ of models) takes 2 minutes on Cast Bench.

### 8.4 Privacy and Data Handling

Critical for EU/German market and developer trust.

- **Ephemeral by default:** Test data processed and deleted immediately after benchmark. Never stored unless explicitly opted in.
- **Encrypted storage:** Saved test suites encrypted at rest with customer-managed keys.
- **GDPR compliant:** Data processing agreement available. No data used for model training. Full deletion on request.
- **Bring-your-own-hardware tier:** Connect your own Mac to the Cast Bench dashboard. Everything runs on your machine — Cast provides orchestration and reporting only. Zero data leaves your network.

### 8.5 Pricing

|                   | Free           | Pro €29/mo   | Team €59/mo                        |
| ----------------- | -------------- | ------------ | ---------------------------------- |
| Benchmark runs    | 3/month        | Unlimited    | Unlimited                          |
| Models per run    | 2              | All (15+)    | All (15+)                          |
| Device profiles   | 1 (local only) | 5            | 5                                  |
| Test data upload  | 10 samples     | 500 samples  | 2,000 samples                      |
| Saved test suites | —              | 5            | Unlimited                          |
| Ground truth eval | —              | Yes          | Yes                                |
| Regression alerts | —              | —            | Yes (new model notifications)      |
| CI/CD integration | —              | —            | Yes (GitHub Actions / Xcode Cloud) |
| Data retention    | Ephemeral only | 30 days      | 90 days                            |
| Team members      | 1              | 1            | 10                                 |
| Quality scoring   | Basic          | LLM-as-judge | LLM-as-judge + custom eval         |

**Free tier** runs benchmarks locally through Cast CLI and uploads results to a dashboard for comparison with community data. Enough to try it once and see the value.

**Pro** is the individual developer building a real app who needs to pick the right model and iterate on their schema.

**Team** is the company with a production app that needs ongoing model monitoring and CI integration.

### 8.6 Unit Economics

A benchmark run with 50 test samples against 5 models is ~250 inference calls. On a Mac Studio M2 Ultra at ~40 tok/s for a 7B model, average 200 tokens per output: ~5 seconds per call, ~20 minutes total for the full matrix. With 2–3 Mac Studios, dozens of Pro customers can be served concurrently.

| Item                                              | Monthly Cost |
| ------------------------------------------------- | ------------ |
| 2× Mac Studio M2 Ultra (amortized over 36 months) | ~€110        |
| Electricity (2 machines, Munich rates)            | ~€50         |
| Hosting/bandwidth (FastAPI + Next.js dashboard)   | ~€50         |
| Total infrastructure                              | ~€210        |

At 100 Pro customers (€29/mo): €2,900/month revenue, ~€210 cost = **~93% gross margin.**

Hardware scales linearly: each additional Mac Studio adds capacity for ~50 more concurrent Pro customers at ~€55/month incremental cost.

### 8.7 Data Flywheel

Every benchmark run generates data about which models work best for which struct shapes. Aggregated anonymously across all users, this builds the most comprehensive model performance database for on-device structured generation.

Possible community features powered by this data:

- "Trending models for extraction tasks this month"
- "Best model for enum classification under 2GB RAM"
- "Average quality improvement from adding @Description annotations"
- Model recommendation engine: upload your schema, get a model suggestion before running a full benchmark

This data makes the free library stickier (community insights) and the paid service more valuable (recommendations improve with scale).

### 8.8 Moat

Cast Bench Cloud is impossible to build without the Cast library. A generic inference API can't benchmark structured output quality against specific Swift schemas with specific annotations. The library and cloud service form a closed loop: the library creates the schemas, the cloud benchmarks them, the results improve library usage, which drives more cloud usage.

Competitors would need to build both the constrained decoding engine and the benchmarking infrastructure to replicate this.

---

## 9. Additional Revenue Paths

### 9.1 Consulting (Immediate, Month 3+)

Once Cast establishes expertise in on-device structured generation:

- **Integration consulting:** "Help us add Cast to our app" — €150–200/hour
- **Model optimization:** "Fine-tune a model for our specific extraction task" — project rates €5–15K
- **Architecture review:** "Review our on-device AI pipeline design" — €2–5K per engagement
- **Training workshops:** Half-day workshops on on-device ML for iOS teams — €2–5K per session

Estimated: €3–10K/month if actively pursued. Freiberufler status already handles tax/legal structure.

### 9.2 Enterprise License (Month 12+)

MIT for everyone. Optional paid "Enterprise License" (€500–2,000/year) that includes:

- Priority support with SLA on bug fixes
- IP indemnification
- Private support channel
- Early access to new features
- Custom model recommendation reports

Large companies pay for legal comfort, not features. Requires Cast to be embedded in production apps at companies with procurement budgets. Nearly zero effort once set up.

### 9.3 Cast as a Product Wedge (Month 6+)

Cast isn't just a library — it's a distribution mechanism. Possible products built on top:

- **On-device AI platform for iOS:** Model management + structured generation + vector search + agent framework. Cast is module one. LangChain but native Swift, local-first.
- **Fine-tuned model marketplace:** Curated MLX models optimized for specific Cast schemas (medical entity extraction, legal clause classification, invoice parsing). Cast users discover they need better models.
- **Vertical apps:** Built with Cast for unfair development speed advantage. Cast knowledge enables shipping AI-native apps faster than competitors.

---

## 10. Launch Strategy

### 10.1 Pre-Launch (Weeks 5–7)

- Build in public: Tweet/post progress on development, share code snippets, benchmark results
- Identify 10–15 iOS developers active in the MLX/on-device-AI space on Twitter/X and Mastodon
- Share early alpha with 3–5 trusted developers for feedback (DMs, not public)
- Write the launch blog post: "I built an App Store app with on-device ML — here's the library I wish existed" (connects to NeatPass story)
- Prepare the example iOS app (SwiftUI, streaming fields populating in real-time)
- Record a 30-second demo video showing typed generation in action

### 10.2 Launch Day

**GitHub:**

- Clean README with quickstart, comparison table (Cast vs alternatives), and benchmark results
- Example code in `/Examples` directory
- Contributing guide

**Hacker News:**

- "Show HN: Cast — `as?` for LLMs. Type-safe structured output from any local model on Apple Silicon"
- Post Tuesday–Thursday, 8–10 AM PT (optimal for HN)
- Engage actively in comments for first 2 hours (critical for velocity)

**Twitter/X:**

- Thread: Problem → solution → code example → demo video → benchmark results → link
- Tag relevant iOS/ML developers
- Pin the thread

**Reddit:**

- r/iOSProgramming, r/swift, r/LocalLLaMA, r/MachineLearning
- Genuine posts explaining the problem and solution, not promotional

**Other:**

- Swift Package Index submission
- iOS Dev Weekly newsletter submission (Dave Verwer curates, accepts open-source tool submissions)
- Submit to iOS Dev Tools (iosdev.tools)

### 10.3 Post-Launch (Weeks 8–12)

- Respond to every GitHub issue within 24 hours
- Ship fixes for bugs reported by early adopters quickly (velocity builds trust)
- Write 2–3 follow-up technical blog posts: "How constrained decoding works," "Benchmarking 10 models for structured output on iPhone," "Cast vs Apple's @Generable"
- Submit conference talk proposals to try! Swift Tokyo (April), Swift Connection, NSSpain
- Engage in the mlx-swift-examples #221 issue thread, link to Cast as a solution
- Start collecting feedback on what Cast Bench Cloud should look like

### 10.4 Growth (Months 3–6)

- Cast Bench Cloud MVP launch
- Publish "State of On-Device Structured Generation" report using anonymized benchmark data
- Guest posts on popular iOS blogs (Swift by Sundell, Hacking with Swift, etc.)
- Contribute improvements upstream to MLX Swift if applicable
- Build relationships with Apple Developer Relations team (they track notable open-source Swift projects)

---

## 11. Target Audience

**Primary: iOS developers adding AI features to apps.** They need reliable structured data from local models — extraction, classification, summarization into typed objects. Currently blocked by unreliable JSON output from small models.

**Secondary: Indie developers building AI-native apps.** Developers like you (NeatPass-style) who want on-device intelligence without cloud API costs or privacy concerns.

**Tertiary: Enterprise iOS teams.** Companies evaluating on-device ML for privacy-sensitive applications in healthcare, finance, and legal. Need production-grade tooling with guarantees.

**Quaternary: MLX ecosystem contributors.** Researchers and developers building the Swift ML tooling layer who will build on top of Cast.

---

## 12. Risk Assessment

| Risk                                                       | Likelihood            | Impact | Mitigation                                                                                                                                                                                                    |
| ---------------------------------------------------------- | --------------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Apple extends `@Generable` to third-party models           | Medium (12–24 months) | High   | Ship fast, build community moat. Apple rarely covers all edge cases — Cast can offer more annotations, more models, better DX. Also, Apple extending support validates the market.                            |
| MLX Swift API changes break Cast                           | Medium                | Medium | Pin to MLX Swift versions. Maintain compatibility matrix. Contribute upstream.                                                                                                                                |
| Small initial audience (Swift + on-device ML is niche)     | High                  | Medium | The audience grows as Apple pushes on-device AI. Early positioning means owning the space when it expands. Even 500 serious developers is enough for consulting revenue.                                      |
| Constrained decoding adds too much latency overhead        | Low                   | High   | Outlines and XGrammar prove <5% overhead is achievable. Benchmark extensively. XGrammar C++ integration as escape hatch.                                                                                      |
| A well-funded competitor builds the same thing             | Low (niche)           | Medium | First-mover advantage in a niche market. Community and ecosystem integration create switching costs. MIT license means even if someone forks, they can't replicate the community.                             |
| Model quality too low for real-world use with small models | Medium                | Medium | This is a model problem, not a Cast problem. Cast makes the best of whatever model you give it. Bench Cloud helps developers find the best model for their task. Document model quality expectations clearly. |

---

## 13. Success Metrics

### Library Metrics

| Timeframe   | Metric                                                     | Target      |
| ----------- | ---------------------------------------------------------- | ----------- |
| Launch week | GitHub stars                                               | 200+        |
| Month 1     | GitHub stars                                               | 500+        |
| Month 1     | Unique cloners/week                                        | 100+        |
| Month 3     | GitHub stars                                               | 1,500+      |
| Month 3     | Contributors (non-author)                                  | 5+          |
| Month 3     | Production apps using Cast                                 | 10+         |
| Month 6     | GitHub stars                                               | 3,000+      |
| Month 6     | Conference talk invitations                                | 1+          |
| Month 6     | Newsletter/blog features                                   | 3+          |
| Year 1      | GitHub stars                                               | 5,000+      |
| Year 1      | Standard tool for on-device structured generation in Swift | Qualitative |

### Revenue Metrics

| Timeframe    | Source                      | Target                 |
| ------------ | --------------------------- | ---------------------- |
| Month 3–6    | Consulting                  | €2–5K/month            |
| Month 6      | Bench Cloud Pro subscribers | 50 (€1,450/month)      |
| Month 9      | Bench Cloud Pro subscribers | 150 (€4,350/month)     |
| Month 12     | Bench Cloud total           | €6,000/month           |
| Month 12     | Enterprise licenses         | 5 (€2,500–10,000/year) |
| Month 12     | Consulting                  | €5–10K/month           |
| Year 1 total | All sources combined        | €8–15K/month           |

---

## 14. Resource Requirements

### Development Phase (Weeks 1–7)

- Time: 15–25 hours/week for 7 weeks
- Hardware: Existing MacBook (M-series) for development and local testing
- Cost: €0 (open-source dependencies, free GitHub, existing hardware)
- Accounts: GitHub, Swift Package Index, HuggingFace (all free)

### Cast Bench Cloud Phase (Months 3–6)

- 2× Mac Mini M4 Pro or Mac Studio M2 Ultra: €1,200–5,000 (one-time)
- FastAPI backend hosting (Railway/Fly.io): €20–50/month
- Next.js dashboard hosting (Vercel): €20/month
- Domain: castbench.dev or bench.cast.dev: €12/year
- Stripe for payments: 2.9% + €0.25 per transaction
- Total monthly operational cost: ~€100–200/month before hardware amortization

### Ongoing

- 5–10 hours/week for maintenance, community support, feature development
- Scales up if consulting or Bench Cloud gains traction

---

## 15. Summary

Cast fills a clear technical gap — the only structured generation library for on-device LLMs in Swift. The combination of a free, high-quality open-source library and a paid cloud benchmarking service creates a self-reinforcing system: the library drives adoption, adoption creates demand for benchmarking, benchmarking generates data that improves model recommendations, which makes the library more valuable.

The project is scoped to ship v1.0 in 7 weeks, requires no external funding, and generates revenue through multiple channels (Bench Cloud, consulting, enterprise licenses) starting 3–6 months post-launch. Even in the worst case where monetization underperforms, Cast establishes deep expertise in an emerging technical niche that compounds into career value, consulting opportunities, and future product optionality.

**First commit: as soon as possible. Ship Phase 1 in 3 weeks. Everything else follows.**
