# Sources/MLXStructured

Vendored from [petrukha-ivan/mlx-swift-structured](https://github.com/petrukha-ivan/mlx-swift-structured), Apache-2.0. The `LICENSE` file in this directory is the upstream's, kept verbatim for attribution. Cast itself is also Apache-2.0 — same license, no segmentation.

## Don't modify casually

The default stance is **don't touch these files**. The reason this code is vendored (rather than pulled as an SPM dependency) is to keep the binding stable while we shape Cast's public API; we expect to merge upstream changes back in periodically.

If you must modify a file:
- Leave the existing header intact (`// Created by Ivan Petrukha on …`).
- Add a one-line marker near the top: `// Modifications: <description> by <author>, <year>`. This is required by Apache-2.0 §4(b) when redistributing modified files.
- Keep modifications surgical — wider refactors should land upstream first, then sync down.

## Folder map

- `Backends/` — adapters between MLX arrays and the underlying grammar engine. `XGrammar.swift` is the bridge to `Sources/CMLXStructured/`.
- `Grammar/` — `Grammar`, `Grammar+Schema.swift`, `Grammar+Structural.swift`, `Grammar+Encoding.swift`. Pure-Swift grammar representation independent of the matching engine.
- `Structural/` — `StructuralTag` and its builder for the structural-output pattern.
- `GrammarMatcher.swift`, `GrammarMatcherFactory.swift`, `GrammarMaskedLogitProcessor.swift` — the runtime path: factory builds a matcher from a tokenizer + grammar, the processor masks invalid tokens during MLX generation.
- `Generate.swift` — the entry point that ties matcher + processor + MLX's `generate()` together.

## SPM gotcha

`LICENSE` in this directory must be in the `MLXStructured` target's `exclude:` list in the root `Package.swift`. Otherwise SPM emits "found 1 file(s) which are unhandled". Don't add other unhandled files here without also excluding them.

## Updating from upstream

Rough procedure (no automation today):
1. Fetch upstream: `git fetch https://github.com/petrukha-ivan/mlx-swift-structured main`.
2. Diff against local: `git diff FETCH_HEAD -- Sources/MLXStructured/`. Review every change.
3. Apply only the bits you want, preserving any local `// Modifications:` markers.
4. Bump the upstream commit SHA in the root `NOTICE` file.
5. Run `swift test` locally (where Metal works) to verify nothing broke.
