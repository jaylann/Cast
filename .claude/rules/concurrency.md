---
paths:
  - "Sources/**/*.swift"
---

# Concurrency Patterns

## Isolation Model
- Services: `actor` when managing shared mutable state (e.g., tokenizer cache, grammar cache)
- Models/DTOs: `struct` conforming to `Sendable`
- Public API: Mark methods `async` — let consumers choose their isolation context
- `nonisolated` explicitly when an actor method doesn't need isolation

## Async Patterns
- Prefer structured concurrency (`async let`, `TaskGroup`) over unstructured `Task {}`
- `AsyncStream` to bridge delegate/callback APIs
- `for await` over `Task` + closure for consuming streams

## Cancellation
- Check `Task.isCancelled` in long-running operations (generation loops)
- `withTaskCancellationHandler` when wrapping MLX generate calls
- Propagate cancellation — never swallow `CancellationError`

## Anti-Patterns
- `DispatchQueue` — use actors or structured concurrency instead
- Unstructured `Task {}` without cancellation handling
- `@Sendable` closures capturing mutable state

## Library-Specific Patterns
- `CastModel` should be an `actor` (manages model state, tokenizer cache)
- Grammar compilation results are `Sendable` value types
- Generation methods return via `async throws` — consumer decides isolation
- Streaming via `AsyncThrowingStream<PartialResult<T>, Error>`
