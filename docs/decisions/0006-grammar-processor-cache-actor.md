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

Cache scope is **per-`CastModel`**: each model owns its own actor instance
(line 17 of `CastModel.swift`). This avoids cross-model interference and
makes `clear()` semantics scoped and obvious.

## Verification

`Tests/CastTests/CacheTests.swift` covers:

- Cache hit (second call returns the same artifact).
- In-flight de-duplication (N concurrent callers run the loader once).
- Retry after failure (failing loader doesn't poison the cache).
- `warmUp` (eager population).
- `clear` (post-clear lookup re-runs the loader).

Tests added in the PR for issue #91.

## Consequences

- No global lock on `cast()`; fan-out is correctly de-duplicated without
  serializing unrelated calls.
- No duplicate Hub fetches under fan-out, removing a class of rate-limit
  failures.
- Cache scope is per-`CastModel`: two `CastModel` instances loading the same
  underlying checkpoint cache independently. Acceptable today (a `CastModel`
  is the natural unit of model lifecycle); revisit if multi-model fan-out
  becomes common.
- The actor boundary serializes mutations to `cache` and `inFlight` but does
  not serialize the loader itself — the loader runs on a detached task and
  the actor only re-enters at completion to install the result.
