# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Project Overview

Cast is a Swift Package that enables type-safe structured output from any local LLM on Apple Silicon via constrained decoding. It uses MLX Swift for inference and Swift macros for compile-time grammar generation. Think `as?` for LLMs.

Repository: `github.com/jaylann/Cast`
License: Apache-2.0
Author: Justin Lanfermann

## Code Standards

Detailed rules live in `.claude/rules/`. Key principles:
- **Swift**: Value types by default, avoid force unwraps/tries/casts. See `swift6.md`, `concurrency.md`.
- **Style**: SwiftFormat + SwiftLint run automatically via PostToolUse hooks. Comments explain WHY not WHAT. See `documentation.md`.
- **Naming**: Engine, Processor, Builder, Cache, Provider, Compiler suffixes. Protocols use `-ing` suffix. See `naming-conventions.md`.
- **Testing**: Swift Testing framework, `swift test`. See `testing.md`.
- **MLX Safety**: GPU ops guidance for library consumers. See `mlx-safety.md`.
- **Parallel Work**: Consider subagents/teams for non-trivial tasks. See `parallel-work.md`.
- **Apple APIs**: Always verify with AppleDocs + web search before using. See `apple-api-verification.md`.
- **Macros**: SwiftSyntax patterns, testing macros. See `macro-development.md`.
- **Release**: Staged workflow — PRs target `stage`, `main` is release-only, semver tags via `release.yml`. See `release-workflow.md`.
- **PR conventions**: Every PR needs exactly one `type:*` label and at least one `area:*` label; milestone if it closes a milestoned issue. CI gate (`pr-conventions.yml`) hard-fails otherwise. See `pr-conventions.md`.
- **ADRs**: Write `docs/decisions/NNNN-*.md` for complex decisions before committing. See `documentation.md`.

## Pre-Commit Workflow

Use `/commit` which runs these steps in order:
1. `/simplify` on changed files
2. Revise CLAUDE.md with learnings
3. Run tests (`swift test`) — skip if changes don't affect testable code
4. Stage only your changes, commit with concise message

Never skip steps. Never commit with failing tests.

## Team Workflow

**Always consider parallelism** for non-trivial tasks. See `.claude/rules/parallel-work.md`.

When running teammates (subagents via Task tool):
- **Before committing**: Each teammate MUST run `/claude-md-management:revise-claude-md`
- **Before terminating**: Each teammate MUST run `/claude-md-management:revise-claude-md`

## Self-Documentation

When you discover or create something useful:
- Append one-line learnings to `## Learnings` below
- Add focused rules to `.claude/rules/` for topic-specific guidance
- See `documentation.md` for ADR and feature doc patterns

## Build and Development Commands

See `build-tooling.md` for full details. Quick reference:
```bash
swift build                    # Build the package
swift test                     # Run all tests
swift test --filter CastTests  # Run specific test target
swift test --filter CastMacroTests  # Run macro tests
swift package resolve          # Resolve dependencies
swift package clean            # Clean build artifacts
```

## Architecture Overview

Cast follows a **6-layer architecture** with **protocol-based dependency injection**:

### Layer 1 — Developer API (`Sources/Cast/API/`)
The only layer developers interact with. `@Castable` macro, property wrappers (`@MaxLength`, `@Range`, etc.), `CastModel`, generation methods (`.cast()`, `.classify()`, `.extract()`).

### Layer 2 — Prompt Engine (`Sources/Cast/Prompt/`)
Auto-constructs prompts from schema + annotations. Handles chat templates per model family (Llama, Qwen, Mistral, etc.).

### Layer 3 — Grammar Compiler (`Sources/CastMacros/`)
Runs at build time inside Swift macro. Converts annotated struct into deterministic grammar. Outputs static state machine skeleton on the type.

### Layer 4 — Tokenizer Linker (`Sources/Cast/Tokenizer/`)
Runtime one-time binding per (model, type) pair. Maps grammar states to concrete token IDs. Cached aggressively.

### Layer 5 — Constrained Sampler (`Sources/Cast/Sampler/`)
Custom LogitsProcessor for MLX Swift's generate(). Reads grammar state, masks invalid tokens, samples only valid continuations.

### Layer 6 — MLX Swift (external dependency)
Model loading, inference, token generation. Cast composes with it, never forks.

## Package Structure

```
Sources/
  Cast/                    # Main library target
    API/                   # Public-facing types: CastModel, property wrappers
    Prompt/                # Prompt construction engine
    Tokenizer/             # Tokenizer-grammar binding and caching
    Sampler/               # Constrained LogitsProcessor
    Schema/                # JSON Schema generation, grammar rules
  CastMacros/              # Macro target (compiler plugin)
    CastMacroPlugin.swift  # Plugin entry point
    CastableMacro.swift    # @Castable macro implementation
Tests/
  CastTests/               # Library tests
  CastMacroTests/          # Macro expansion tests
docs/
  decisions/               # Architecture Decision Records
```

## Learnings
<!-- Append discovered patterns, gotchas, and project-specific knowledge below -->
- `swift build`/`swift test` inside the Claude Code sandbox fails with `sandbox-exec: sandbox_apply: Operation not permitted` / `Invalid manifest` — SwiftPM compiles `Package.swift` under its own nested `sandbox-exec`, which the outer sandbox blocks. Run with `dangerouslyDisableSandbox: true` (Bash tool flag). This is the recurring failure mode for SPM-based subagents working in `$TMPDIR/Cast-worktrees/<name>/`.
- `@Castable` consumers need `import Cast` **plus** `import Collections` and `import JSONSchema` — the macro expansion references `JSONSchema` and `OrderedDictionary` directly and the library does not `@_exported`-re-export them.
- Runnable examples live in `Examples/` (own `Package.swift`, `.package(path: "..")`); each is `Examples/Sources/<Name>/main.swift`, registered as an `executableTarget`. CI is `.github/workflows/examples.yml` — `swift build` only, no auto-run.
- DocC site lives at `Sources/Cast/Cast.docc/`. Each `Examples/Sources/<Name>/main.swift` is mirrored to a `Cast.docc/Examples/<Name>.md` article via `scripts/generate-example-docs.sh`; CI (`.github/workflows/docs.yml`) regenerates before building, so committed articles can drift but the published site never does. When adding a new example, also add a `<doc:Name>` entry under `## Topics > Examples` in `Cast.docc/Cast.md`.
- Default branch is `stage`, not `main`. PRs target `stage`. `main` is release-only and updated exclusively by `.github/workflows/release.yml` (workflow_dispatch, semver input, fast-forwards `stage`→`main`, tags `vX.Y.Z`, creates GitHub Release). See `.claude/rules/release-workflow.md` (see docs/decisions/0004-staged-release-model.md).
- License is **Apache-2.0 unified** across the package. `LICENSE` (root) + `NOTICE` credits the two vendored upstreams (`petrukha-ivan/mlx-swift-structured` → `Sources/MLXStructured/`, `mlc-ai/xgrammar` submodule → `Sources/CMLXStructured/xgrammar/`). Both upstreams are also Apache-2.0; their LICENSE is preserved in-tree. Don't relicense; don't add GPL/LGPL/AGPL vendored code without explicit decision. (see docs/decisions/0002-license-unification.md)
- `Sources/MLXStructured/LICENSE` must be in the `MLXStructured` target's `exclude:` list in `Package.swift` — SPM otherwise emits an "unhandled file" warning. (see docs/decisions/0002-license-unification.md)
- CI (`macos-15`) cannot run MLX runtime tests — `swift test` exits with `MLX error: Failed to load the default metallib`. Tests that invoke MLX use the `.requiresMetal` Swift Testing trait (in `Tests/CastTests/TestHelpers.swift` and `Tests/MLXStructuredTests/TestHelpers.swift`) which skips when `CI=true`. Macro/schema/property-wrapper/validator/prompt-engine/JSON-repair tests do NOT need this gate. See issue #75. (see docs/decisions/0005-requires-metal-test-trait.md)
- `scripts/pre-public-check.sh` is the safety scanner used before any visibility change, history rewrite, or accepting CI-touching contributions. Exit `0` = safe; `1` = findings.
- Repo is **public** at `https://github.com/jaylann/Cast`. Standard `macos-15` runners are free with no minute cap on public repos. Never switch workflows to `macos-15-large` / `-xlarge` — those "larger runners" are billed even on public repos.
- `.claude/` is gitignored (line 41 of `.gitignore`). Files under `.claude/rules/`, `.claude/hooks/`, and `.claude/settings.json` are local-only per-developer config — they don't ship with the repo. CLAUDE.md at the root IS tracked.
- `MLXModelContainer.perform { context in ... }` closure is `@Sendable` — captured `var`s from the enclosing scope can't be mutated inside (Swift 6 concurrency error). To surface in-flight state out of the closure (e.g. last buffer for `CastError.cancelled(partialOutput:)` recovery), wrap it in a small `final class ... : @unchecked Sendable` lock-protected holder. Closure return value is cleaner when state only needs to flow on the success path.
- Parallel-PR git worktrees can't live in `../Cast.worktrees/` — the Claude Code sandbox only allows writes inside the repo (`.`) or `$TMPDIR`. Use `$TMPDIR/Cast-worktrees/<name>` (e.g. `/tmp/claude-501/Cast-worktrees/streaming`) and `git worktree add -b feat/<x> "$TMPDIR/Cast-worktrees/<name>" stage`. They're ephemeral but survive long enough to push branches and open PRs.
- New `CastModel+*` extensions whose signatures use `GenerateDisposition` need `@preconcurrency import MLXLMCommon` — the type lives in `MLXLMCommon`, not `MLXStructured` (`MLXStructured.generate` *takes* it but doesn't define it). `CastModel+Generation.swift` is the canonical reference for the import set.
- `@Castable`'s `@attached(member, names:)` declaration in `Sources/CastMacros/CastableMacro.swift` must list every synthesized name explicitly (`named(castSchema)`, `named(init)`, `named(PartiallyGenerated)`, …). Adding a new member without updating this list **silently fails** — the macro emits the decl but the compiler hides it from consumers. If a synthesized type/method works in macro-expansion tests but isn't visible from `Sources/Cast/`, this is the first place to look.
- The `CastTests` test target gained `JSONSchema` + `Collections` dependencies in `Package.swift` once tests started using `@Castable` — every `@Castable` consumer (library code OR tests) needs both. Add the products to the test-target's `dependencies:` when introducing the first `@Castable` test in a new test target.
- `Examples/Package.swift` uses `.package(path: "..")`, and SPM derives the path-package identifier from the **parent directory name** — not the `name:` field in the parent's `Package.swift`. Building `Examples/` from a git worktree whose dir is anything other than `Cast` (e.g. `$TMPDIR/Cast-worktrees/<feature>`) fails with `unknown package 'Cast'` for every target. CI is unaffected (it checks out into `Cast/`); for local Examples builds in a worktree, build inside the main `Cast/` checkout instead.
- Canonical label taxonomy is `type:*` / `area:*` / `priority:*` (see `.claude/rules/pr-conventions.md`). The legacy flat labels (`api`, `macro`, `prompt`, `safety`, `infra`, `schema`, `constraints`, `testing`, `performance`, `tooling`, `compat`, `examples`, `docs`) and `phase-0..3` were retired on 2026-04-30 — milestones replaced phase labels. Every PR needs ≥1 `type:` and ≥1 `area:`; CI gate `pr-conventions.yml` enforces this and skips Dependabot.
- `.github/workflows/claude.yml` and `claude-code-review.yml` were removed on 2026-04-30: the Claude Code GitHub App (https://github.com/apps/claude) wasn't installed on the repo, so every `claude-review` run failed `401 Unauthorized` on app-token exchange. Re-add the workflows only after installing the App.
- Chat templates are owned by MLXLMCommon's `processor.prepare(input:)`. Cast hands a flat `"\(system)\n\n\(prompt)"` string. Verified in Qwen-2.5/Llama-3.2/Mistral-v0.3/Phi-3.5/Gemma-2 via `Tests/CastTests/ChatTemplateTests.swift`; ADR `docs/decisions/0001-chat-template-handling.md`.
- GitHub PR review threads stay `isResolved: false` even after the fix commit lands — they don't auto-close on a follow-up push. When delegating "fix review feedback" work, the agent must explicitly resolve each addressed thread via the GraphQL `resolveReviewThread` mutation (`gh api graphql -f query='mutation { resolveReviewThread(input: {threadId: "<id>"}) { thread { isResolved } } }'`). Get thread IDs with `pullRequest(number: N).reviewThreads`. Leave deferred-to-follow-up threads open and link the new issue in a reply.
- Repo merge policy is **squash-only** (set 2026-04-30 via `gh api -X PATCH repos/jaylann/Cast`): `allow_merge_commit=false`, `allow_rebase_merge=false`, `allow_squash_merge=true`. `gh pr merge --merge` / `--rebase` will fail; use `--squash` or no flag.
- `CastableDiagnostic` (`Sources/CastMacros/CastableDiagnostic.swift`) supports per-case `severity`. The early-return guard in `CastableMacro.expansion` MUST filter on `severity == .error` (not `diagnostics.isEmpty`) — otherwise adding a `.warning` case silently blocks all macro expansion for any consumer that triggers the warning. Pattern: `let hasError = diagnostics.contains { $0.0.severity == .error }; guard !hasError else { return [] }`. Test new warning cases by asserting both the `DiagnosticSpec(severity: .warning)` AND the full `expandedSource` to confirm expansion still produced members.
- `import Hub` (from `huggingface/swift-transformers`) is **not** transitively re-exported through `MLXLMCommon`/`MLXStructured` — adding `HubApi` directly to a `Sources/Cast/` file requires `.product(name: "Hub", package: "swift-transformers")` on the `Cast` target in `Package.swift`. `Hub` is already in `MLXStructured`'s deps but downstream targets pulling in `Cast` don't see it without the explicit edge. Surfaced when adding `ModelSource.customEndpoint` (#101).
- Git worktrees created off this repo do **not** inherit submodule checkouts — `git submodule update --init --recursive` must be re-run inside the worktree before the first `swift build`, otherwise SPM emits `Invalid Exclude '…/CMLXStructured/xgrammar/…': File not found` warnings and the build fails to find xgrammar headers. CLAUDE.md mentions this for fresh clones; same applies to `git worktree add` outputs.
