# 0002 — License unification (Apache-2.0)

## Status

Accepted.

## Context

Cast vendors two upstream projects and risks license fragmentation as new
vendored code lands:

- `Sources/MLXStructured/` — in-tree source vendoring of
  `petrukha-ivan/mlx-swift-structured` (Apache-2.0).
- `Sources/CMLXStructured/xgrammar/` — git submodule of `mlc-ai/xgrammar`
  (Apache-2.0).

Both upstreams are Apache-2.0 today, but without an explicit policy a future
contribution could pull in a permissive-but-incompatible upstream (or worse, a
copyleft one) and leave downstream consumers in an unclear redistribution
position.

## Decision

Cast and every vendored upstream are **Apache-2.0**. Concretely:

- New vendored code MUST be Apache-2.0-compatible: Apache-2.0, MIT, BSD-2, or
  BSD-3. **GPL / AGPL / LGPL are prohibited** without an explicit ADR-level
  decision.
- The upstream `LICENSE` file is preserved in-tree alongside the vendored
  code (`Sources/MLXStructured/LICENSE`, `Sources/CMLXStructured/xgrammar/LICENSE`).
- Each vendored upstream is credited in the root `NOTICE` with: project name,
  URL, copyright holder, license identifier, vendoring path, and ideally the
  upstream commit SHA at the time of vendoring.
- Modifications to vendored files keep the original header intact and add a
  one-line `// Modifications: <description> by <author>, <year>` marker per
  Apache-2.0 §4(b).

## Verification

- `LICENSE` lives at the repo root and identifies the package as Apache-2.0.
- `NOTICE` lists both vendored upstreams (`petrukha-ivan/mlx-swift-structured`,
  `mlc-ai/xgrammar`) with the metadata above.
- `Sources/MLXStructured/LICENSE` is in the `MLXStructured` target's
  `exclude:` list in `Package.swift` — SPM otherwise emits an "unhandled file"
  warning.

## Consequences

- A single license simplifies attribution and downstream redistribution; users
  do not have to reason about multiple compatible-but-distinct license texts.
- Any new vendored dependency requires explicit license review before landing.
  The default answer to "can we vendor this?" is "only if it's Apache-2.0,
  MIT, BSD-2, or BSD-3."
- Vendored upstreams that later relicense (rare but possible) trigger a fresh
  ADR; we do not silently follow the upstream change.
