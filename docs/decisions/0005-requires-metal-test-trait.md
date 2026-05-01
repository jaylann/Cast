# 0005 — `.requiresMetal` test trait

## Status

Accepted.

## Context

GitHub-hosted `macos-15` runners are virtualized M1 instances without access
to the Metal stack the host can use. Tests that trigger MLX array operations
crash with:

```
MLX error: Failed to load the default metallib
```

This is not a Cast bug; it is a property of the runner environment (see
issue #75). Without a gate, every CI run that loads an MLX model fails.

## Decision

Define a project-local Swift Testing trait `.requiresMetal`
(`Trait where Self == Testing.ConditionTrait`) that skips the test whenever
the `CI` environment variable is defined (any value — GitHub Actions
sets `CI=true`, but the trait's check is `ProcessInfo.processInfo.environment["CI"] == nil`).

Apply the trait **only** to tests that actually invoke MLX runtime:

- Model-loading tests
- End-to-end `cast()` / `castStream()` tests
- Chat-template smoke tests against real model checkpoints

Do **not** apply the trait to tests that don't touch MLX runtime:

- Macro expansion tests
- Schema generation tests
- Property-wrapper tests
- Validator tests
- Prompt-engine tests
- JSON-repair tests
- Classification tests that operate on synthetic outputs

Gating non-MLX tests would silently shrink CI coverage.

## Verification

- The trait is defined in **two** files, one per test target:
  `Tests/CastTests/TestHelpers.swift` and
  `Tests/MLXStructuredTests/TestHelpers.swift`. Swift Testing traits are
  not transparently shared across test targets, so each target gets its own
  copy.
- Local Apple Silicon runs every test (no `CI` env var set), exercising the
  Metal-dependent code path that CI skips.
- CI runs (`CI=true`) skip the metal-gated tests and run everything else.

## Consequences

- Two trait files maintained in lockstep. If one diverges, the targets'
  CI behavior diverges.
- Review burden on adding a new test reduces to one question: "does this
  touch MLX runtime?" If yes, add `.requiresMetal`. If no, leave it ungated.
- A future change to the runner environment (e.g. GitHub Actions exposing
  Metal on `macos-15`) makes the trait a no-op without code change — it
  short-circuits on the `CI` env var being defined, not on capability
  detection. Switching to capability detection would be a follow-up ADR.
