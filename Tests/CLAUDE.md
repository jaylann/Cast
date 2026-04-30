# Tests

All targets use [Swift Testing](https://developer.apple.com/documentation/testing) (`@Test`, `@Suite`, `#expect`), not XCTest. Run with `swift test` (or `swift test --filter <TargetName>` for a focused subset).

## Test targets

- `CastTests/` — main library tests: API shape, schema generation, property wrappers, validators, prompt engine, JSON repair, classification, error types.
- `CastMacroTests/` — `@Castable` macro expansion tests via `assertMacroExpansion`. Pure compile-time, no runtime dependencies.
- `MLXStructuredTests/` — vendored test suite for the grammar matcher / structural tag / generation paths. Many of these touch MLX runtime.

## CI vs local: the `.requiresMetal` trait

GitHub-hosted `macos-15` runners can't load `default.metallib`, so any test that triggers MLX runtime crashes the test process. The project defines a Swift Testing trait that **skips** affected tests when `CI=true`:

```swift
@Test("Llama loads", .requiresMetal)
func loadsModel() async throws { … }
```

Definitions live in:
- `Tests/CastTests/TestHelpers.swift`
- `Tests/MLXStructuredTests/TestHelpers.swift`

(Each test target needs its own copy; Swift Testing traits aren't transparently shared across targets.)

**Apply `.requiresMetal` only to tests that actually invoke MLX.** Macro tests, schema generation, property-wrapper introspection, validator logic, prompt-template assembly, JSON-repair logic, classification logic, configuration types — none of these need Metal. Tagging them would silently shrink CI coverage. When in doubt: write the test without the trait, run `CI=true swift test`, and only add the trait if it crashes with a metallib error.

Local development on Apple Silicon runs every test (the env var isn't set), so you don't lose coverage when shipping.

## Conventions

- One `@Suite` per concept (`@Suite("Classify")`, `@Suite("PromptEngine")`); flat `@Test` functions inside.
- Test names read as English sentences: `func stringEnumCastSchemaProviding()` → "String CastEnum conforms to CastSchemaProviding".
- Performance tests use `@Test` with timing assertions, not `XCTMeasure`. Tagging them `.requiresMetal` is usually correct since they exercise model loading.
- Async tests use `async throws`; `#expect(throws: ...)` for expected error paths.
- Helpers (test fixtures, custom traits) live in `TestHelpers.swift` per target — keep one file per target rather than splitting into many.

## Running

```bash
swift test                          # all tests, locally (Metal available)
CI=true swift test                  # mimic CI: MLX-runtime tests skip
swift test --filter CastMacroTests  # macros only
swift test --filter MLXStructured   # vendored grammar/matcher tests
```

For test-writing patterns and TDD workflow, see `.claude/agents/swift-test-writer.md` and `.claude/rules/testing.md`.
