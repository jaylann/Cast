# 0007 — `JSONSchema.excluding(fields:)` regex round-trip

## Status

Accepted.

## Context

`Sources/Cast/Schema/JSONSchema+Excluding.swift` exposes
`JSONSchema.excluding(fields:)`, which removes named fields from a schema for
callers that need a derived schema — for example, extracting only some
properties from a larger `@Castable` type.

`JSONSchema` is a non-uniform indirect enum: each case carries different
associated values, and the structural shape of "drop a property and remove
its name from `required`" varies case-by-case.

## Decision

Implement `excluding(fields:)` as a JSON round-trip with a regex mutation in
the middle:

1. Encode the `JSONSchema` to JSON (`JSONEncoder`).
2. Apply regex substitutions on the encoded JSON:
   - Remove matching properties from the `properties` object.
   - Remove matching names from the `required` array.
3. Decode the mutated JSON back to a `JSONSchema` (`JSONDecoder`).

This was chosen over a custom `Encoder` (or a structural mutating visitor
over the enum) because the case-by-case rewrite would mirror `JSONSchema`'s
non-uniform indirect-enum shape, which is significantly more code than the
regex pass and equally fragile under upstream additions of new cases.

## Verification

`Tests/CastTests/SchemaExcludingTests.swift` exercises the full round-trip:
non-trivial nested schemas, multi-field exclusion, no-op exclusion (field
not present), and the `required`-array invariant (excluded fields don't
remain required).

## Consequences

- Cost is one encode + one decode per call. Acceptable while
  `excluding(fields:)` is called at most once per generation; not in a hot
  loop.
- Switching to a structural rewrite would require a custom mutating visitor
  over every `JSONSchema` case, and would have to track upstream additions.
  Worth doing only if the cost ever shows up in profiling.
- **Risk**: a future `JSONSchema` case whose JSON serialization is
  meaningfully different from today's shape (e.g. arrays-of-objects with
  required entries inside) could trip the regex. The test suite catches
  this — any regex mismatch surfaces as a decode failure or an unexpected
  schema delta.
- The regex approach is opaque to readers compared to a structural rewrite;
  the file's WHY comment and this ADR are the entry points for explaining
  why the implementation looks the way it does.
