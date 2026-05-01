# Copilot instructions for Cast

Cast is a Swift Package that produces type-safe structured output from local LLMs on Apple Silicon via constrained decoding (MLX Swift + Swift macros). License: **Apache-2.0**.

## Code rules

- **Swift 6 strict concurrency.** Value types by default. Sendable closures captured by reference cannot mutate `var` in their enclosing scope.
- **No force-unwraps, force-tries, or force-casts** (`!`, `try!`, `as!`) anywhere in `Sources/`. In tests use `#require`, never `!`.
- **Naming suffixes**: `Engine`, `Processor`, `Builder`, `Cache`, `Provider`, `Compiler`. Protocols use `-ing` suffix (e.g. `Sampling`, `Tokenizing`).
- **Comments explain WHY, not WHAT.** Default to no comments. Don't reference the current task, fix, or callers.
- **Public API** lives in `Sources/Cast/API/CastModel+<Surface>.swift`. A new surface = a new file (e.g. `CastModel+Stream.swift` for streaming). Don't overload an existing surface file.

## Tests

- Use the **Swift Testing** framework (`import Testing`) — `#expect` / `#require`. Not XCTest.
- MLX runtime tests **must** carry the `.requiresMetal` trait — CI runners (`macos-15`) cannot load Metal and crash with `Failed to load the default metallib`. Macro/schema/property-wrapper/validator/prompt-engine/JSON-repair tests do not need this trait.
- Macro tests use `assertMacroExpansion`. New diagnostic warning cases need both `DiagnosticSpec(severity: .warning)` AND a full `expandedSource` assertion.

## Macros (`Sources/CastMacros/`)

- `@attached(member, names:)` MUST list every synthesized name explicitly (`named(castSchema)`, `named(init)`, …). A new synthesized member without an entry silently fails — the macro emits the decl but the compiler hides it.
- `CastableDiagnostic` supports per-case severity. The early-return guard MUST filter on `severity == .error`, not `diagnostics.isEmpty`. Otherwise a new `.warning` case silently blocks all macro expansion.

## Architecture

Six layers, protocol-based DI:
1. Developer API (`Sources/Cast/API/`) — `@Castable`, property wrappers, `CastModel`, generation entrypoints.
2. Prompt engine (`Sources/Cast/Prompt/`) — auto-constructs prompts; chat templates owned by MLXLMCommon's `processor.prepare(input:)`.
3. Grammar compiler (`Sources/CastMacros/`) — build-time grammar from annotated struct.
4. Tokenizer linker (`Sources/Cast/Tokenizer/`) — runtime binding per (model, type), cached.
5. Constrained sampler (`Sources/Cast/Sampler/`) — custom LogitsProcessor masks invalid tokens.
6. MLX Swift (external) — composed with, never forked.

## Workflow

- **PRs target `stage`**, never `main`. `main` is release-only and is updated only by `.github/workflows/release.yml`.
- Every PR needs **exactly one `type:*` label** and **at least one `area:*` label**. CI gate `pr-conventions.yml` enforces. Full taxonomy: `.claude/rules/pr-conventions.md`.
- **Squash-merge only.** `--merge` and `--rebase` are disabled at the repo level.
- New vendored code must be Apache-2.0-compatible (Apache-2.0, MIT, BSD-2/3 — never GPL/AGPL/LGPL). Preserve the upstream `LICENSE` and add a `NOTICE` entry. See `.claude/rules/release-workflow.md`.

## Don't

- Don't push directly to `main` or `stage`. PR + review only.
- Don't switch GitHub Actions runners to `macos-15-large` / `-xlarge` — those are billed even on public repos. Stay on `macos-15`.
- Don't introduce dependencies under GPL/AGPL/LGPL.
- Don't add `Co-Authored-By` trailers to commits.
- Don't add backwards-compat shims, dead-code comments, or feature flags for hypothetical future use.
