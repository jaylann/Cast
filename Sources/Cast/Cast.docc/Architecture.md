# Architecture

How Cast composes a Swift type, a JSON schema, a grammar, and an MLX
sampler into typed structured output.

## The six layers

Cast keeps the layers thin and composable; you can reach into any of them
without forking the library.

```
┌─────────────────────────────────────────────────┐
│ 1. Developer API                                │  Sources/Cast/API
│    @Castable, property wrappers, CastModel.     │
├─────────────────────────────────────────────────┤
│ 2. Prompt Engine                                │  Sources/Cast/Prompt
│    Builds the system + user prompt from schema. │
├─────────────────────────────────────────────────┤
│ 3. Grammar Compiler (build time)                │  Sources/CastMacros
│    @Castable expansion synthesizes castSchema.  │
├─────────────────────────────────────────────────┤
│ 4. Tokenizer Linker (one-time per model+type)   │  Sources/Cast/Tokenizer
│    Maps grammar states to concrete token IDs.   │
├─────────────────────────────────────────────────┤
│ 5. Constrained Sampler                          │  Sources/MLXStructured
│    Custom LogitsProcessor: masks invalid tokens.│
├─────────────────────────────────────────────────┤
│ 6. MLX Swift                                    │  external dependency
│    Model loading, inference.                    │
└─────────────────────────────────────────────────┘
```

### 1. Developer API

The only layer most users touch. ``CastModel``, the `@Castable` macro, and
the property wrappers. Surface goal: *if it compiles, it produces valid
output of the requested type.*

### 2. Prompt Engine

Composes the system + user message from the JSON schema and any
`@Description` / `@Examples` annotations the user attached. Per-model
chat templates (Llama / Qwen / Mistral) are
[#37](https://github.com/jaylann/Cast/issues/37); today the engine emits
a generic JSON-schema prompt that works best with instruct-tuned models.

### 3. Grammar Compiler

Runs at build time inside the macro plugin. Walks the struct's stored
properties, projects each one into a JSON Schema fragment (using the
attached property wrappers), and emits a static `castSchema` plus a
matching `init(from:)`. Build-time means: no reflection at runtime, no
string-templated grammar surprises.

### 4. Tokenizer Linker

Bridges the grammar to the loaded model's tokenizer. The linker resolves
each grammar state to the token IDs the *current* model can emit, and
caches the mapping per `(model, type)`. ``CastModel/prepare(_:)`` is the
public hook to pay this cost up front.

### 5. Constrained Sampler

A custom `LogitsProcessor` for MLX Swift's `generate()`. Before each
sample it reads the grammar state, masks logits for tokens that would
break the schema, and lets the underlying sampler choose only from the
valid continuations. This is what makes the output *guaranteed* parsable
rather than *probably* parsable.

### 6. MLX Swift

External dependency. Model loading, KV cache, inference. Cast composes
with it — does not fork it.

## Lifetime of a `cast(...)` call

```
cast(prompt) ──► PromptEngine.build ──► (system, user)
                       │
                       ▼
              SchemaGenerator + macro-emitted castSchema
                       │
                       ▼
              Grammar + tokenizer mapping (cached)
                       │
                       ▼
              container.perform { MLXStructured.generate(...) }
                       │
                  ┌────┴─────┐
                  ▼          ▼
         Token-by-token   didGenerate hook
         masking via      (token budget,
         GrammarMasked    Task.isCancelled)
         LogitProcessor
                       │
                       ▼
              Raw JSON string
                       │
                       ▼
              JSONRepair (if config.repairTruncatedJSON)
                       │
                       ▼
              ValidatorSupport.decode → T
```

A ``CastConfiguration/timeout`` wraps the entire `container.perform`
block in a task-group race; an external `Task.cancel()` propagates the
same way. Both paths run ``CastModel`` cleanup before throwing
``CastError/timedOut(partialOutput:)`` or
``CastError/cancelled(partialOutput:)``.

## Concurrency model

``CastModel`` is `Sendable`. Multiple concurrent `cast(...)` calls share
the underlying `ModelContainer` (MLX serializes them internally), and
each call registers its cancellation closure in a per-model in-flight
registry — that's what powers ``CastModel/abortInFlight()`` and the iOS
background hook in ``CastModel/enableBackgroundSafety()``.
