# 0004 — Staged release model (stage default, main release-only)

## Status

Accepted.

## Context

A single-default-branch repo tempts unsafe direct pushes during day-to-day
work, and conflates "integration tip" with "released artifact." Cast publishes
DocC, ships semver tags, and is auto-indexed by Swift Package Index — each of
those wants a stable, release-only branch to anchor against.

## Decision

Cast uses a two-branch staged release model:

- **`stage`** is the default branch and the PR target. Every contribution
  lands on `stage` first. CI (`Test`, `Build Examples`) runs on every PR and
  every push to `stage`.
- **`main`** is release-only. It is advanced exclusively by
  `.github/workflows/release.yml` (`workflow_dispatch`, semver input). The
  workflow validates semver, checks tag uniqueness, verifies stage CI is
  green for the current `stage` HEAD, fast-forwards `stage` → `main`, tags
  `vX.Y.Z`, and creates a GitHub Release with auto-generated notes.
- DocC publishes from `main` via `.github/workflows/docs.yml`. Swift Package
  Index auto-indexes new tags.

Branch protection (live on origin):

- `main`: linear history required, force-push blocked, deletion blocked.
- `stage`: force-push blocked, deletion blocked.

Merge policy is **squash-only** at the repo level:

- `allow_merge_commit=false`
- `allow_rebase_merge=false`
- `allow_squash_merge=true`

`gh pr merge --merge` and `gh pr merge --rebase` therefore fail by policy;
use `--squash` or no flag.

## Verification

- Branch protection live on origin (verified 2026-04-30 against the public
  repo).
- `.github/workflows/release.yml` exists and implements the workflow above.
- `.claude/rules/release-workflow.md` is the maintainer reference for the
  release procedure (note: the `.claude/` directory is gitignored, so this
  file is local-only per-developer config; the workflow itself is the
  source of truth).

## Consequences

- Releases never bypass CI gating: `main` only ever fast-forwards from a
  CI-green `stage` HEAD.
- A maintainer-only escape hatch exists for emergency releases when the CI
  gate is itself broken (manual `git tag -a vX.Y.Z` + `git push` +
  `gh release create`). It is to be used only after manual `swift test`
  verification on Apple Silicon. The escape hatch is documented; it is not
  the normal path.
- Contributors can never push directly to `main`; the Release workflow is the
  only intended path.
- History rewrites on either branch after the public flip break downstream
  references (forks, archived clones, third-party caches), so we don't.
