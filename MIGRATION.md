# Migrating an existing project to Cast

This is the doc you wish you'd had on day one. It targets the two failure modes that most often blow up real migrations:

1. **`Sendable & Decodable` conformance** — the public generation API gates on it, and existing model types often don't conform without changes.
2. **Bad/empty/garbage output at runtime** — the model "works" but the JSON is wrong, fields are empty, or generation never terminates cleanly.

If something here contradicts the README, this doc wins.

---

## 1. Sendable & Decodable: the why

`CastModel.cast<T: Decodable & Sendable>(...)` requires the type you decode into to be both `Decodable` and `Sendable`. Same for `castJSON`, `classify`, and `prepare`.

The `@Castable` macro now synthesizes `Decodable` for you. `Sendable` is left to Swift's value-type synthesis: a struct is automatically `Sendable` if every stored property is `Sendable`. There's no magic that bypasses these constraints — if your existing type can't satisfy them, you have to refactor it.

### Pre-flight checklist

For each existing type you want to migrate, walk these in order:

- [ ] **Is it a `struct`?** Classes, actors, and `enum` (other than raw-value via `CastEnum`) are not supported by `@Castable`. The macro emits a `requiresStruct` diagnostic for non-structs.
- [ ] **Are all stored properties `Sendable`?** Closures, `class` references, `weak` refs, `NSObject` subclasses, and most `AnyObject`-typed values are not.
- [ ] **Are all stored properties `Decodable`?** Primitives (`String`, `Int`, `Double`, `Float`, `Bool`), arrays of `Decodable`, optionals of `Decodable`, and other `@Castable` types are fine. Custom *user-defined* types with `init(from:)` are fine; Foundation value types (`Date`, `URL`, `UUID`, `Data`, `Decimal`) are covered separately below.
- [ ] **Are nested types also `@Castable`** (or otherwise `Decodable`)?
- [ ] **No bare Foundation value types as fields.** `Date`, `URL`, `UUID`, `Data`, `Decimal` raise a compile-time `unknownNonPrimitiveType` error in v1.0+. See the *Foundation types* section below for the two supported workarounds.
- [ ] **No generics with unbounded type parameters.** The macro reads syntactic types and won't infer constraints; if you need `MyType<T>`, give it `<T: Decodable & Sendable>` and don't expect the macro to do that for you.

If every box is ticked, `@Castable struct Foo { ... }` will compile and `model.cast(_, as: Foo.self)` will work.

### Common Sendable refactors

**Closure stored on the model.** Move it off — the model is data; the behavior belongs with the caller.

```swift
// Before
struct Form {
    var title: String
    var onSubmit: () -> Void   // not Sendable, not Decodable
}

// After
struct Form {
    var title: String
}
// onSubmit lives in the view / view-model, not in the value
```

**Class reference inside a value.** Split into a DTO + a wrapper.

```swift
// Before
struct UserCard {
    var name: String
    var avatar: UIImage?       // class, not Sendable across actors
}

// After
struct UserCardDTO: Decodable, Sendable {   // <- this is what you @Castable
    var name: String
    var avatarURL: URL?
}

@MainActor
final class UserCardView { /* loads UIImage from URL */ }
```

**`Codable` already declared on the type.** Keep it. The macro adds `Decodable`, and a redundant `Decodable` conformance is a hard error. Either remove your explicit `Decodable` (the macro covers it) or keep `Decodable` on yours and don't apply `@Castable`.

**Mutating methods.** Fine on `struct`s — they don't break `Sendable`.

### Why the macro doesn't synthesize `Sendable` explicitly

We tried. The trade-off:

- If the macro adds `extension Foo: Sendable {}`, users who already declare `Sendable` (or `final class … : Sendable`) get a redundant-conformance error.
- If we leave it to value-type synthesis, structs with non-Sendable members fail at the *call site* (`cast<T: Sendable>`) with a clearer "type X is not Sendable" pointing to the offending member.

The latter gives better error messages, so that's the default.

---

## 2. Output quality: bad / empty / garbage

If `cast()` returns but the JSON decodes wrong, the fields are empty, or generation hangs, work this list top-down. Cheapest fixes first.

### Pick the right model

The single biggest quality lever. **Use an instruct-tuned model.** Cast's prompt template is currently generic JSON-schema text (per-model chat templates are #37); base/completion models often go off the rails. Good starting points on Apple Silicon:

- `mlx-community/Llama-3.2-3B-Instruct-4bit` — small, fast, decent
- `mlx-community/Qwen2.5-7B-Instruct-4bit` — better quality, more memory
- `mlx-community/Mistral-7B-Instruct-v0.3-4bit`

If you're on a base model, that's your problem. Switch.

### Lower the temperature

```swift
var config = CastConfiguration()
config.temperature = 0.0     // deterministic
config.topP = 1.0
let r: Recipe = try await model.cast("...", config: config)
```

For extraction or classification, `0.0` is almost always right.

### Use the soft constraints

The grammar constrains *shape*. To shape *content*, use the soft annotations:

```swift
@Castable
struct Invoice {
    @Description("Total amount including tax, in USD, two decimal places.")
    @Precision(2)
    var total: Double = 0.0

    @Examples("INV-001", "INV-002")
    var number: String = ""
}
```

`@Description` and `@Examples` are placed verbatim in the schema; instruct-tuned models pick them up.

### Warm the grammar

The first call for a `(model, type)` pair compiles the grammar (a few hundred ms to a few seconds depending on schema size). Do it once at startup:

```swift
try await model.prepare(Invoice.self, Recipe.self)
```

Subsequent calls reuse the cached grammar.

### Cap runaway generation

Set a wall-clock timeout on the call:

```swift
var config = CastConfiguration()
config.timeout = .seconds(10)
let r: Recipe = try await model.cast("...", config: config)
// throws CastError.timedOut(partialOutput:) on deadline
```

For a token-count cap (cheaper than wall clock), use `didGenerate`:

```swift
let r: Recipe = try await model.cast(
    "...",
    didGenerate: { tokens in
        tokens > 256 ? .stop : .more
    }
)
```

`Task.cancel()` from your call site is also honored — the call throws
`CastError.cancelled(partialOutput:)`. **Behavior change since 0.x:**
cancellation no longer surfaces as `CastError.decodingFailed` — match the
new case if you previously caught the decoding-failed path.

### Gotcha: post-decode constraint values are zero

```swift
@Castable
struct Profile {
    @MaxLength(100) var name: String = ""
}
let p: Profile = try await model.cast("...")
print(p.$name)        // <- not what you'd hope for
print(p._name.maxLength)   // 0, not 100
```

The grammar constrains the *generated* output, but the wrapper's stored constraint resets to zero on decode (`Sources/Cast/API/PropertyWrappers.swift:23–28` for `MaxLength` and similar for the others). If you need the constraint at runtime — for client-side validation, UI hints, etc. — store it yourself in a separate static or pass it explicitly.

This is intentional but surprising; we'd like to fix it without breaking the wrapper API. No tracking issue yet — file one if it bites you.

### Field-name mismatch

`@Castable` uses your Swift property names verbatim as JSON keys. If your existing payloads use snake_case and you've been relying on a custom `CodingKeys`, two options:

- Rename the Swift properties to match the JSON. (Usually fine for new code.)
- Keep your `CodingKeys` enum — it overrides the macro's generated decoding. Verify the schema generator picks up the right keys for your case (file a bug if not).

### Truncation

If the model emits valid JSON up to the `maxTokens` limit and then stops mid-object, Cast attempts a best-effort repair (close strings/containers, drop dangling fragments). When repair succeeds, decoding proceeds normally; when it can't, the call throws ``CastError/repairFailed(rawOutput:reason:)`` with the original (un-repaired) tail.

To opt out:

```swift
var config = CastConfiguration()
config.repairTruncatedJSON = false
```

Other knobs:

- Bump `config.maxTokens`.
- Trim your schema (smaller types decode faster, less risk of truncation).
- Use `castJSON` and inspect the raw output to confirm the issue is truncation vs. a hallucinated field. `castJSON` never repairs — by contract, callers asked for raw bytes.

---

## 3. Foundation types

The `@Castable` macro recognizes a fixed set of primitives (`String`, `Int`, `Double`, `Float`, `Bool`, arrays of those, plus other `@Castable` structs). Foundation value types — `Date`, `URL`, `UUID`, `Data`, `Decimal` — are **not** primitives from the macro's perspective: it can't synthesize a JSON Schema or grammar for them.

> **Breaking change in the v1.0 line (currently on `stage`, not yet released):** prior versions emitted a *warning* and let expansion proceed; the consumer's downstream compile error was `<TypeName>.PartiallyGenerated?` — cryptic and hard to trace. As of v1.0, an `unknownNonPrimitiveType` field is a compile **error** at the macro site so the diagnostic is what you see, not a chain reaction in synthesized code.

### Workaround 1: pre-convert at the model boundary

Make the field a primitive that round-trips through JSON, and convert in your application code:

```swift
@Castable
struct Event {
    var whenISO8601: String = ""   // instead of Date
    var idString: String = ""      // instead of UUID
    var attachmentBase64: String = "" // instead of Data
}

let event: Event = try await model.cast("…")
let when = ISO8601DateFormatter().date(from: event.whenISO8601)
```

This is the path most consumers take; it keeps the schema small and the prompt easy for the model to satisfy.

### Workaround 2: wrap the Foundation type in a small `@Castable`

If you genuinely want the field to read as `Date` at the call site, give the macro a struct it can synthesize:

```swift
@Castable
struct ISODate {
    var iso8601: String = ""
}

@Castable
struct Event {
    var when: ISODate = ISODate()
}
```

Then derive a `Date` from `event.when.iso8601` at the call site.

---

## Known sharp edges (and where to follow them)

| Issue | Status | Workaround until then |
|---|---|---|
| Per-model chat templates ([#37](https://github.com/jaylann/Cast/issues/37)) | open | Use instruct-tuned models; the generic template works best with them |
| Truncated JSON detection / repair ([#40](https://github.com/jaylann/Cast/issues/40)) | shipped | `repairTruncatedJSON` defaults `true`; opt out via `CastConfiguration` |
| Timeout / cancellation API ([#41](https://github.com/jaylann/Cast/issues/41)) | shipped | `CastConfiguration.timeout`, `CastError.timedOut`, `CastError.cancelled` |
| Background/foreground GPU lifecycle ([#42](https://github.com/jaylann/Cast/issues/42)) | shipped (iOS, opt-in) | `model.enableBackgroundSafety()` |
| Streaming partial decoding ([#35](https://github.com/jaylann/Cast/issues/35)) | open | Currently: blocking `cast()` only |
| `extract()` convenience ([#36](https://github.com/jaylann/Cast/issues/36)) | open | Use `cast` with a dedicated extraction `@Castable` type |

---

## Still stuck?

Open an issue with:

1. The `@Castable` struct you're trying to use (or a minimal reproduction).
2. The exact compile error or the JSON the model produced.
3. The model ID you loaded.

That's enough to triage.
