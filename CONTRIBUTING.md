# Contributing to Cast

Thanks for your interest in contributing to Cast! This guide covers setup, conventions, and the PR/release workflow.

## Development Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/jaylann/Cast.git
   cd Cast
   ```

2. **Build the package**
   ```bash
   swift build
   ```

3. **Run tests**
   ```bash
   swift test
   ```

### Requirements

- macOS 14+ with Apple Silicon (for MLX runtime tests; macro/schema/prompt tests run anywhere)
- Xcode 16+ or Swift 6.0+ toolchain
- SwiftFormat (`brew install swiftformat`)
- SwiftLint (`brew install swiftlint`)

## Branching & Release Workflow

Cast uses a **staged release model**. Two long-lived branches:

- **`stage`** — default integration branch. **PRs target `stage`.** CI runs on every push and PR.
- **`main`** — release-only. Updated exclusively by the `release.yml` workflow (fast-forward from `stage`, tag, GitHub Release). DocC publishes from `main`.

Never open a PR against `main`. See `.claude/rules/release-workflow.md` and ADR `docs/decisions/0004-staged-release-model.md` for the full model.

### Branch Naming

- `feat/castable-macro` — new features
- `fix/tokenizer-cache-miss` — bug fixes
- `refactor/grammar-engine` — refactoring
- `docs/api-examples` — documentation

### Code Style

SwiftFormat and SwiftLint enforce style automatically:
- Config: `.swiftformat`, `.swiftlint.yml` at the project root
- Manual run: `swiftformat .` and `swiftlint --fix`

Comments explain **why**, not what. Default to no comments. See `.claude/rules/` for deeper guidance.

### Testing

- All PRs must pass `swift test`.
- New features require tests; bug fixes should include a regression test.
- Use the **Swift Testing** framework (`import Testing`) — `#expect` / `#require`, not XCTest.
- Macro changes need expansion tests using `assertMacroExpansion`.
- **MLX runtime tests must use the `.requiresMetal` trait** — CI runners (`macos-15`) cannot load Metal and skip these. See `Tests/CastTests/TestHelpers.swift`. Macro/schema/prompt-engine/property-wrapper/JSON-repair tests do **not** need this trait.

## Picking a `CastModel+*.swift` file

`Sources/Cast/API/` splits the `CastModel` surface across six extension files. Use the table below when adding a new method so it lands in the right one — the file each method lives in is its surface contract.

| File | Owns | Don't put here |
|---|---|---|
| `CastModel+Generation.swift` | every blocking generation entrypoint: `cast`, `castJSON`, `classify` | streaming, extraction-flavored prompts |
| `CastModel+Stream.swift` | `castStream` and partial-decode helpers | blocking generation |
| `CastModel+Extract.swift` | `extract(from:as:instruction:…)` and future extraction-shaped APIs | unrelated prompt templates |
| `CastModel+Lifecycle.swift` | `abortInFlight()`, iOS background-safety hooks | model load/unload (the core `CastModel` type) |
| `CastModel+Timeout.swift` | internal cross-isolation glue (`withGenerationTimeout`, `withInFlightRegistration`) | new public API |
| `CastModel+GPUSafety.swift` | Metal/MLX lifecycle plumbing (`cleanupGPU`, global error handler) | code that doesn't touch `MLX.Stream` / `Memory` |

If a new method doesn't fit any existing surface, add a new `CastModel+<Surface>.swift` rather than overloading one of the above.

## Pull Request Process

1. Fork the repository.
2. Create a feature branch from `stage`.
3. Make your changes; ensure `swift test` passes.
4. **Open a PR against `stage`.** Fill out the PR template.
5. Squash-merge once review is complete (squash is the only allowed merge mode).

### PR Guidelines

- Keep PRs focused — one feature or fix per PR.
- Write a clear description of what and why.
- Reference related issues with `Closes #XX`.
- Respond to review feedback promptly.

### Required Labels

Every PR **must** carry exactly one `type:*` label and at least one `area:*` label. If the PR closes a milestoned issue, add the same milestone. CI gate `pr-conventions.yml` blocks merge otherwise.

| Prefix | What |
|---|---|
| `type:bug` / `type:feature` / `type:enhancement` / `type:refactor` / `type:chore` / `type:docs` / `type:test` | kind of change (one) |
| `area:api` / `area:macro` / `area:grammar` / `area:sampler` / `area:tokenizer` / `area:prompt` / `area:schema` / `area:safety` / `area:mlx` / `area:examples` / `area:docs` / `area:ci` / `area:tests` / `area:performance` / `area:tooling` / `area:compat` / `area:benchmarking` | subsystem (one or more) |

Full taxonomy and worked examples: `.claude/rules/pr-conventions.md`.

### Review Process

PRs receive automated review from:
- **CodeRabbit** — line-level review, posts inline comments and a walkthrough on every push. Marks the PR approved once threads are resolved and CI is green.
- **GitHub Copilot** — high-level review on PR open.

Address or push back on each comment in-thread. A maintainer review and squash-merge follows.

## License

By contributing, you agree that your contributions will be licensed under the **Apache License 2.0** (the project's license — see `LICENSE`). New vendored code must be Apache-2.0 compatible (Apache-2.0, MIT, BSD-2/3); preserve the upstream `LICENSE` and add a `NOTICE` entry. See `.claude/rules/release-workflow.md` for the full rule.

## Filing Issues

- Use the issue templates (bug report or feature request).
- Search existing issues before creating a new one.
- Include reproduction steps for bugs.
- Be specific about expected vs actual behavior.
- Security issues: **do not** file a public issue. See `SECURITY.md`.

## Claude Code (optional)

If you use [Claude Code](https://claude.com/claude-code) for development, the repo ships project-specific config under `.claude/`:

- `.claude/rules/` — project rules (PR conventions, release workflow).
- `.claude/agents/` — Cast-specific subagents (`spm-builder`, `swift-expert`, `swift-test-writer`).
- `.claude/skills/` — slash commands (`/build`, `/commit`).
- `.claude/hooks/` — session hooks (e.g. CLAUDE.md learnings reminder on stop).
- `.claude/settings.json` — baseline shared settings (formatter PostToolUse hooks).

Per-developer state stays local: `.claude/settings.local.json`, `.claude/worktrees/`, and any `.credentials.json` are gitignored — set up your own permissions and MCP servers there.
