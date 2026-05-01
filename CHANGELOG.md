# Changelog

All notable changes to Cast are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

GitHub Releases (auto-generated from squash-merged PR titles) remain the canonical source per release; this file is the human-readable summary kept under git so users can read it offline.

## [Unreleased]

### Added

- `CastModel.extract(from:as:instruction:…)` — extraction-flavored entrypoint.
- `CastModel.castStream(...)` — `AsyncSequence` of `PartialResult<T>` for streaming partial decoding.

## [0.1.0] - 2026-04-30

First public release. Cast ships as an Apache-2.0 Swift Package: type-safe structured output from any local LLM on Apple Silicon via constrained decoding.

### Added

- `@Castable` macro that synthesizes JSON Schema, `Decodable`, and a `PartiallyGenerated` mirror from an annotated struct.
- `CastModel` with `cast`, `castJSON`, and `classify` entrypoints; `init(wrapping:configuration:)` for caller-managed `ModelContainer` lifetimes.
- Property wrappers covering schema constraints: `@MaxLength`/`@MinLength`, `@Count`/`@MaxCount`/`@MinCount`, `@CastRange`, `@Precision`, `@Pattern`, `@OneOf`, `@Description`, `@Examples`, `@Nullable`, `@DefaultValue`, `@Validator`.
- `JSONSchema.excluding(fields:)` for dynamic schema modification at call time.
- `CastModel.prepare(_:)` warm-up to pay grammar-compilation cost upfront.
- `didGenerate` callback for cooperative cancellation; `abortInFlight()` plus iOS background-safety hooks (`enableBackgroundSafety()` / `disableBackgroundSafety()`).
- DocC documentation site auto-generated from runnable `Examples/` snippets.
- README, MIGRATION guide, security policy, and contributing guide.

### Changed

- License unified to **Apache-2.0** across the package, including vendored upstreams (`petrukha-ivan/mlx-swift-structured` and `mlc-ai/xgrammar`); attribution preserved in `NOTICE`.
- Repository moved to a staged release model: `stage` is the integration branch and PR target, `main` is release-only and updated by `.github/workflows/release.yml`.

### Fixed

- `@Castable` now synthesizes `Decodable` conformance for the consumer.
- `MLXStructured/LICENSE` is excluded from the SPM target so the build no longer warns about an unhandled file.
- xgrammar pinned to `v0.1.34` with `tvm_ffi` python bindings excluded.

### Infrastructure

- Manual release workflow (`release.yml`) with semver validation, tag uniqueness check, and CI-green gate before fast-forwarding `stage` → `main`.
- `pre-public-check.sh` safety scanner (secrets, gitleaks, fork-PR audit) for every visibility / history change.
- CI skips MLX runtime tests on `macos-15` runners via the `.requiresMetal` Swift Testing trait.

[Unreleased]: https://github.com/jaylann/Cast/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/jaylann/Cast/releases/tag/v0.1.0
