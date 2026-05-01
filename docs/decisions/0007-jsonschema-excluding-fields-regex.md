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

Implement `excluding(fields:)` as a JSON round-trip with a small mutation
in the middle:

1. Encode the `JSONSchema` to JSON via `JSONEncoder` (with `.sortedKeys`).
2. Apply a single regex substitution on the encoded JSON string to strip
   the macro-emitted `__[0-9]+__` placeholder suffix that `JSONSchema`'s
   encoded form carries (e.g. property keys like `name__1__` become
   `name`). The regex only touches that placeholder pattern; it does
   **not** rewrite `properties` or `required` directly.
3. Parse the cleaned JSON back into `[String: Any]` via
   `JSONSerialization.jsonObject(...)`.
4. Mutate the dictionary structurally:
   - Remove the excluded keys from the top-level `properties` object.
   - Drop the excluded names from the `required` array; if `required`
     becomes empty, remove the key entirely.
5. Re-encode the mutated dictionary with `JSONSerialization.data(...)` and
   feed the resulting string to `JSONSchema(jsonString:)`.

There is no `JSONDecoder` in the loop. The structural step is a plain
dictionary mutation, not regex over `properties`/`required` slices.

This was chosen over a custom `Encoder` (or a structural mutating visitor
over the enum) because the case-by-case rewrite would mirror `JSONSchema`'s
non-uniform indirect-enum shape, which is significantly more code than the
encode → mutate → re-decode round-trip and equally fragile under upstream
additions of new cases.

## Verification

`Tests/CastTests/SchemaExcludingTests.swift` exercises flat object
schemas: removing one or more properties, the `required`-array invariant
(excluded fields don't remain required, and the key is dropped entirely
when `required` becomes empty), no-op exclusion (field not present),
empty-set short-circuit, preservation of per-property constraints
(`maxLength`, `minimum`/`maximum`), and exclusion of enum-typed fields.
Deeply nested object-of-object exclusion is not yet covered; the regex
in step 2 only targets the macro placeholder suffix and so should be
unaffected by nesting, but treat the test bed as "flat-object behavior
verified" rather than "all shapes verified."

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
