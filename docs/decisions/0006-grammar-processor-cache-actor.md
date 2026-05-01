# 0006 — `GrammarProcessorCache` actor with in-flight de-duplication

## Status

Accepted.

## Context

Tokenizer artifact loading is non-trivial: Hub fetch (network), tokenizer
parse, vocabulary build. A single `cast()` call can take hundreds of
milliseconds the first time per `(model, type)` pair.

Multiple concurrent `cast()` calls for the same `(model, type)` pair —
common under fan-out workloads — would otherwise:

1. Duplicate the Hub fetch (wasted bandwidth, rate-limit risk).
2. Duplicate the tokenizer parse + vocab build (wasted CPU).
3. Race the cache (non-deterministic which loader wins).

A naive `[String: TokenizerArtifacts]` cache wrapped in a lock solves (3) but
not (1) or (2): the lock serializes lookups, but each unique-key miss still
runs the full loader independently.

## Decision

`Sources/Cast/API/GrammarProcessorCache.swift` defines an `actor` keyed on
`ModelConfiguration.name` with two pieces of state:

- `cache: [String: TokenizerArtifacts]` — resolved entries.
- `inFlight: [String: Task<TokenizerArtifacts, any Error>]` — pending loads.

Lookup logic:

1. If the key is in `cache`, return immediately.
2. If the key is in `inFlight`, `await` the existing task's `value`. All
   concurrent callers for the same in-flight key share the same task.
3. Otherwise, create a new task, install it in `inFlight`, run the loader,
   and on completion move the value to `cache` and remove the key from
   `inFlight`.

Failure path: the task completes with an error, the key is removed from
`inFlight`, and the next call retries from scratch (transient Hub failures
should not poison the cache).

Cache scope is **per-`CastModel`**: each model owns its own
`GrammarProcessorCache` instance (held by `CastModel`). This avoids
cross-model interference and makes `clear()` semantics scoped and obvious.

## Verification

`Tests/CastTests/CacheTests.swift` currently covers the smoke surface only:

- `prepare` throws `CastError.modelNotLoaded` when no model is wired up.
- `clear()` runs without error.

The richer behaviors described in the Decision section — cache hit,
in-flight de-duplication under fan-out, retry-after-failure, and
`warmUp` — are not yet exercised in the test suite. Adding them is
tracked separately (issue #91); this ADR documents the intended
semantics so the test additions have a contract to verify against.

## Consequences

- No global lock on `cast()`; fan-out is correctly de-duplicated without
  serializing unrelated calls.
- No duplicate Hub fetches under fan-out, removing a class of rate-limit
  failures.
- Cache scope is per-`CastModel`: two `CastModel` instances loading the same
  underlying checkpoint cache the artifacts independently. Acceptable today
  (a `CastModel` is the natural unit of model lifecycle); revisit if
  multi-model fan-out becomes common.
- The actor boundary serializes mutations to `cache` and `inFlight` but does
  not serialize the loader itself — the loader runs in a separate
  unstructured `Task { … }` so concurrent callers for distinct keys don't
  block each other on the network/parse step. The actor method awaits
  `task.value` directly and resumes inside the actor to install the result.
