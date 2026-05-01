# Release Workflow

Cast uses a staged release model: `stage` is the default integration branch, `main` is release-only.

## Branching model

- **`stage`** — default branch. **PRs target `stage`**, never `main`. CI (`Test`, `Build Examples`) runs on every PR + every push to stage.
- **`main`** — release-only. Updated solely by the `release.yml` workflow via fast-forward push from `stage`. DocC publishes from `main` (`docs.yml`). All semver tags live on `main`.
- **Branch protection** (live on origin):
  - `main`: linear history required, force-push blocked, deletion blocked.
  - `stage`: force-push blocked, deletion blocked.

## Release process

1. Wait for the latest `Test` workflow run on `stage` HEAD to be green.
2. Trigger the `Release` workflow via `gh workflow run release.yml -f version=X.Y.Z` (or the Actions UI). Semver, no `v` prefix in input.
3. The workflow validates semver, checks tag uniqueness, verifies stage CI is green for the *current* stage HEAD, fast-forwards `main` → `stage`, tags `vX.Y.Z`, creates a GitHub Release with auto-generated notes.
4. `docs.yml` redeploys DocC from `main`. Swift Package Index auto-indexes the new tag.

If the CI gate blocks releases (e.g. while issue #75 is open), the maintainer-only escape hatch is:

```bash
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z
gh release create vX.Y.Z --target main --generate-notes
```

Only use this after manually verifying `swift test` passes locally.

## Pre-public-check

`scripts/pre-public-check.sh` runs the safety scan that gated the original public flip: secret patterns in git history, gitleaks, suspicious files, .gitignore sanity, fork-PR security audit, commit author audit, branch hygiene. Re-run it any time the repo's visibility, history, or contributor surface materially changes — e.g. before accepting a contribution that touches CI, before changing visibility back, after a force-push.

```bash
./scripts/pre-public-check.sh
```

Exit `0` = safe; `1` = findings to address.

## License obligations

Cast is **Apache-2.0** unified across the package, including the vendored `Sources/MLXStructured/` (originally `petrukha-ivan/mlx-swift-structured`) and the `Sources/CMLXStructured/xgrammar` git submodule (`mlc-ai/xgrammar`). When adding any new vendored code:

1. Verify the upstream's license is **Apache-2.0 compatible** (Apache-2.0, MIT, BSD-2/3 — *not* GPL/AGPL/LGPL without explicit decision).
2. Preserve the upstream `LICENSE` file alongside the vendored code.
3. Add an entry to the top-level `NOTICE` crediting the upstream (project name, URL, copyright holder, license, vendoring path, ideally upstream commit SHA).
4. If you modify any vendored file, leave the original header intact and add a one-line `// Modifications: <description> by <author>, <year>` near the top.

Don't relicense Apache-2.0 code as something else. The unified license is what makes attribution sane — keep it that way.

## MLX runtime tests on CI

GitHub-hosted `macos-15` runners are virtualized M1 instances without the Metal stack the host has access to. Tests that trigger MLX array operations crash with `MLX error: Failed to load the default metallib`.

Tests requiring real Metal must opt out of CI execution. Use the project's `.requiresMetal` Swift Testing trait (defined in `Tests/MLXStructuredTests/TestHelpers.swift` once issue #75 lands) — it skips the test when `CI=true` is set in the environment, which is the case on every GitHub Actions run.

```swift
@Test("Llama loads under default config", .requiresMetal)
func loadsModel() async throws { ... }
```

Don't gate macro/schema/property-wrapper/validator/prompt-engine/JSON-repair tests with this — they don't touch MLX runtime and should keep running on CI. The trait is *only* for tests that actually invoke MLX.

## GitHub API gotchas (learned the hard way)

If automating any visibility/protection/security change against this repo (or a similar one), watch out for these:

- **Visibility-change lock window.** Right after `gh repo edit --visibility public --accept-visibility-change-consequences` the repo is briefly locked: any subsequent `gh api PUT /repos/.../branches/.../protection` call returns HTTP 403 `"Repository has been locked"` for roughly 10–30 seconds while GitHub re-indexes. Retry with backoff (5×15s is plenty in practice).
- **Branch protection on free private repos is unavailable.** Classic branch protection is paid-plan-only on private repos and free on public repos. So the order *must* be: flip public first, then add protection. Trying it before the flip returns a generic-looking error.
- **Fork-PR approval is UI-only.** The setting "Fork pull request workflows from outside collaborators" (Settings → Actions → General) has no REST API on free public repos. `gh api PUT /repos/.../actions/permissions/access` rejects with `"Access policy only applies to internal and private repositories"`. The default for new public repos is "Require approval for first-time contributors" which is reasonable; bumping to "all outside collaborators" requires the UI.
- **`git filter-repo` removes the `origin` remote** as a safety measure after rewriting history. Re-add it (`git remote add origin <url>`) before you can force-push. It also creates `.git/filter-repo/commit-map` (old SHA → new SHA) which is useful for finding dangling references afterward.
- **History rewrite orphans SHAs referenced in issue/PR conversation comments.** Issue close-comments often say "Landed in <sha>". After rewriting, those SHAs orphan and the commit links 404 once GitHub GCs (~30–90 days). Fix pattern: enumerate via `gh api --paginate /repos/{owner}/{repo}/issues/comments`, regex-match each old SHA prefix from the commit-map, and PATCH each comment with the new SHA. PR review comments live at a separate endpoint (`/repos/.../pulls/comments`); both need scanning.
- **`gh pr merge --auto` is a no-op without repo-level auto-merge enabled.** If the repo's "Allow auto-merge" setting (Settings → General → Pull Requests) is off, `--auto` silently does *not* engage and the command falls back to whatever other flag is present (`--merge` / `--squash` / `--rebase`), merging immediately without waiting for CI. To genuinely require CI before merge, either enable auto-merge in repo settings *and* configure required status checks in branch protection, or just don't use `--auto` and merge manually after CI completes. Don't have an agent run `gh pr merge` unattended.
- **Repository ruleset bypass actors**: for a personal repo (no org), the canonical bypass entry is `{"actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always"}` — `actor_id: 5` is the Admin role. Other RepositoryRole IDs (Maintain/Write/Triage/Read) are inconsistent across GitHub docs/forum posts; verified by creating ruleset `stage protection` and confirming `current_user_can_bypass: always` on the response.
- **Secret-scanning extras silently no-op via REST API.** `gh api -X PATCH repos/jaylann/Cast -f security_and_analysis.secret_scanning_non_provider_patterns.status=enabled` returns 200 OK with the full repo body, but the setting stays `disabled` in the same response. Same for `secret_scanning_validity_checks`. Toggle these via the Settings → Code security and analysis UI instead. (Other repo settings like `delete_branch_on_merge` PATCH normally.)

## Don'ts

- Don't push directly to `main`. The Release workflow is the only intended path.
- Don't open PRs against `main`. They target `stage`.
- Don't rewrite history on `main` or `stage` after the public flip — every subsequent rewrite breaks more downstream references (forks, archived clones, third-party caches).
- Don't add `Co-Authored-By` trailers to commits. The user has explicit feedback against attribution trailers.
