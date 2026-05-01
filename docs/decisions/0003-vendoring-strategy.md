# 0003 — Vendoring strategy (in-tree vs. submodule)

## Status

Accepted.

## Context

Cast depends on two upstream projects that are not consumed as plain SwiftPM
dependencies:

- `Sources/MLXStructured/` — pure-Swift sources from
  `petrukha-ivan/mlx-swift-structured`, copied directly into the repo.
- `Sources/CMLXStructured/xgrammar/` — C/C++ sources from `mlc-ai/xgrammar`,
  consumed as a git submodule and exposed to SwiftPM via `path:` on the
  `CMLXStructured` target.

The choice of vendoring mechanism per upstream was deliberate, not historical
accident.

## Decision

The mechanism is chosen by the nature of the upstream:

- **In-tree source vendoring** for pure-Swift upstreams whose API surface we
  expect to shape. Binding stability matters: we want to be able to evolve
  call sites, refine types, and accept patches against the in-tree copy
  without waiting on upstream review. `MLXStructured` falls in this bucket.
- **Git submodule** for C/C++ upstreams whose code we don't modify and whose
  build product we consume largely as-is. SPM exposes the submodule directory
  via `path:` on a target. `xgrammar` falls in this bucket.

In both cases, modifications use Apache-2.0 §4(b) `// Modifications:` markers
(see ADR 0002).

## Verification

- `Sources/MLXStructured/CLAUDE.md` documents the periodic upstream-merge
  procedure end-to-end (fetch upstream, three-way merge, resolve, re-test,
  bump the commit-SHA reference in `NOTICE`).
- `Sources/CMLXStructured/xgrammar/` is registered in `.gitmodules`; fresh
  clones initialize it via `git submodule update --init --recursive`.

## Consequences

- `MLXStructured` requires periodic upstream merge work; the cost is ours and
  the procedure is the documented escape valve.
- Fresh clones that skip `git submodule update --init --recursive` fail to
  build with missing-header errors from `xgrammar`. The README install
  snippet calls this out.
- Switching either upstream's vendoring mechanism (e.g. promoting
  `MLXStructured` to a real SwiftPM dependency once its API is stable) is a
  follow-up ADR.
