# PR Conventions

Every PR opened against this repo carries metadata that lets us slice work by kind (bug, feature, docs…), by part of the codebase, and by release. This rule is **mandatory for every Claude agent that runs `gh pr create`**. It is enforced as a hard CI gate (`.github/workflows/pr-conventions.yml`) — a PR without proper labels fails its check.

## Mandatory rule

Every `gh pr create` invocation MUST include:

- Exactly one `--label "type:X"` flag.
- At least one `--label "area:Y"` flag.
- A `--milestone "<title>"` flag if the PR closes any milestoned issue (currently `Phase 3: Polish + v1.0`; future releases use `vX.Y`).

After creation, verify with `gh pr view <N> --json labels,milestone`. If anything is missing, fix immediately with `gh pr edit <N> --add-label "..." --milestone "..."`.

Dependabot PRs are exempt — they're auto-labeled with `dependencies` + ecosystem labels, and the CI gate skips them by author.

## Label taxonomy

### `type:*` — kind of change (exactly one)

| Label              | When to use                                              |
|--------------------|----------------------------------------------------------|
| `type:bug`         | Fixing something broken — wrong output, crash, regression |
| `type:feature`     | Net-new functionality the public API didn't have before  |
| `type:enhancement` | Improving an existing feature (perf, ergonomics, UX)     |
| `type:refactor`    | Internal restructuring; no behavior change               |
| `type:chore`       | Build, CI, deps, repo hygiene                            |
| `type:docs`        | Docs-only — README, DocC, ADRs, comments                 |
| `type:test`        | Test-only — adding/fixing tests, no production change    |

### `area:*` — part of codebase (one or more)

Pick by which `Sources/` or repo subtree the diff touches:

| Label              | Maps to                                                       |
|--------------------|---------------------------------------------------------------|
| `area:api`         | `Sources/Cast/API/` — `CastModel`, property wrappers, `CastError`, public surface |
| `area:macro`       | `Sources/CastMacros/` — `@Castable` macro, SwiftSyntax        |
| `area:grammar`     | `Sources/Cast/Schema/` grammar rules, state machines          |
| `area:sampler`     | `Sources/Cast/Sampler/` — constrained sampling, logit masking |
| `area:tokenizer`   | `Sources/Cast/Tokenizer/` — tokenizer binding, caching        |
| `area:prompt`      | `Sources/Cast/Prompt/` — prompt engine, chat templates        |
| `area:schema`      | `Sources/Cast/Schema/` — JSON schema generation               |
| `area:safety`      | GPU lifecycle, error handling, cancellation                   |
| `area:mlx`         | MLX Swift integration, vendored `Sources/MLXStructured/`      |
| `area:benchmarking`| `CastBench`, perf measurement                                 |
| `area:examples`    | `Examples/` subpackage                                        |
| `area:docs`        | `Sources/Cast/Cast.docc/`, README, `docs/decisions/`          |
| `area:ci`          | `.github/workflows/`, build infra, scripts                    |
| `area:tests`       | `Tests/` infrastructure (helpers, fixtures); for tests OF a specific area, use that area's label + `type:test` |
| `area:performance` | Cross-cutting perf work                                       |
| `area:tooling`     | Developer tooling, scripts                                    |
| `area:compat`      | Model/platform compatibility                                  |

A PR can carry multiple `area:*` labels when it spans subsystems. A macro change that also touches the public API gets `area:macro` + `area:api`.

### `priority:*` — optional, mainly for issues

`priority:critical` (blocks release), `priority:high` (next sprint), `priority:medium` (normal), `priority:low` (backlog). PRs typically don't need a priority label.

## Picking labels — decision flow

1. **`type:` from the diff intent**:
   - Net-new public API or capability → `type:feature`
   - Improves something that already shipped → `type:enhancement`
   - Restores broken behavior → `type:bug`
   - Pure restructure, no behavior delta → `type:refactor`
   - Pure docs → `type:docs`; pure tests → `type:test`
   - Build, CI, deps → `type:chore`

2. **`area:` from `git diff --name-only stage...HEAD`**:
   - Group changed paths by `Sources/<dir>/` or top-level subtree.
   - Each distinct subtree maps to one `area:*` label.
   - Cross-cutting concerns (perf, safety) get an additional area label.

3. **Milestone**: if the PR has `Closes #N` and that issue has a milestone, the PR gets the same milestone. If the PR closes nothing milestoned, omit `--milestone`.

## Worked examples

**Feature PR closing a milestoned issue** (e.g. `castStream()` → `Sources/Cast/API/`):

```bash
gh pr create \
  --base stage \
  --title "feat(api): castStream() — AsyncSequence of PartialResult<T> (#35)" \
  --body "$(cat <<'EOF'
## Summary
- Add streaming generation that yields partial results.

## Test Plan
- [ ] `swift test` passes
- [ ] New tests added for streaming

Closes #35
EOF
)" \
  --label "type:feature" \
  --label "area:api" \
  --milestone "Phase 3: Polish + v1.0"
```

**Bug-fix PR** (e.g. fix a tokenizer cache invalidation):

```bash
gh pr create \
  --label "type:bug" \
  --label "area:tokenizer" \
  --milestone "Phase 3: Polish + v1.0" \
  --base stage --title "fix(tokenizer): invalidate cache on model swap" --body "..."
```

**Docs-only PR** (e.g. README clarification):

```bash
gh pr create \
  --label "type:docs" \
  --label "area:docs" \
  --base stage --title "docs: clarify install snippet" --body "..."
```

**CI workflow tweak**:

```bash
gh pr create \
  --label "type:chore" \
  --label "area:ci" \
  --base stage --title "ci: pin actions/checkout to v6" --body "..."
```

**Cross-subsystem PR** (e.g. macro change that exposes new API):

```bash
gh pr create \
  --label "type:feature" \
  --label "area:macro" \
  --label "area:api" \
  --milestone "Phase 3: Polish + v1.0" \
  --base stage --title "feat(macro): synthesize CastModel.extract()" --body "..."
```

**Dependabot PR**: don't touch — `dependencies` + ecosystem labels are auto-applied and the CI gate skips Dependabot.

## Post-create verification

```bash
gh pr view <N> --json labels,milestone --jq '{labels: [.labels[].name], milestone: .milestone.title}'
```

Expected output shape:
```json
{"labels": ["type:feature", "area:api"], "milestone": "Phase 3: Polish + v1.0"}
```

If a label is missing:
```bash
gh pr edit <N> --add-label "type:feature" --add-label "area:api" --milestone "Phase 3: Polish + v1.0"
```

## What used to be here

The repo previously ran two parallel label systems: the canonical prefixed set and a flat legacy set (`api`, `macro`, `safety`, `infra`, `phase-0..3`, etc.). The legacy labels were retired on 2026-04-30 and migrated into the prefixed taxonomy. Don't reintroduce them.
