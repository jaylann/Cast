# Cast Examples

Runnable Swift programs that demonstrate the current state of the public Cast API.
Each example is a standalone executable target with one source file. CI on this
package builds (does not run) every example whenever `Sources/Cast/**` or
`Examples/**` changes — a public-API change that breaks an example breaks CI.

## Running an example

From inside this directory:

```bash
cd Examples
swift run HelloCast
```

Examples that load a model will download it on first run via the Hugging Face
cache. Default model: `mlx-community/Llama-3.2-3B-Instruct-4bit`.

## Examples

| Target                    | Issue | What it shows                                                    |
| ------------------------- | ----- | ---------------------------------------------------------------- |
| `Smoketest`               | #62   | Imports Cast and prints `ok`. CI build sentinel.                 |
| `HelloCast`               | #63   | `CastModel.load` + a single `@Castable` struct + `cast(_:)`.     |
| `PropertyWrappersTour`    | #64   | Every shipped property wrapper in one struct.                    |
| `NestedTypes`             | #65   | Nested `@Castable` structs and arrays of them.                   |
| `Classify`                | #66   | `CastEnum` for `String`- and `Int`-raw enums via `classify`.     |
| `GenerationModes`         | #67   | Four generation surfaces side-by-side (`cast`/`castJSON` × auto/explicit). |
| `Cancellation`            | #68   | `didGenerate` token budget + `Task.cancel` (workaround for #41). |
| `PrepareWarmup`           | #69   | `prepare()` cold-vs-warm timings for grammar compilation.        |
| `CallerManagedLoading`    | #70   | `CastModel(wrapping:configuration:)` with a shared container.    |
| `ValidatorAndExcluding`   | #71   | `@Validator` transforms + `JSONSchema.excluding(fields:)`.       |
| `ErrorHandling`           | #72   | Every `CastError` case and the recommended user reaction.        |

## Convention for new examples

- File: `Examples/Sources/<Name>/main.swift`, one source file per target.
- Top-of-file comment: `// What this shows: ...` summarising scope in 1–3 lines.
- Aim for ~30 lines of code (excluding the comment header and trailing sample).
- Default model: `mlx-community/Llama-3.2-3B-Instruct-4bit` unless the example
  needs another one — say so if you change it.
- Trailing comment block with a representative sample output produced during
  local manual verification before merging.
- Add a row to the table above and a target entry in `Package.swift`.

## CI

`.github/workflows/examples.yml` runs `swift build` from this directory on PRs
that touch `Sources/Cast/**` or `Examples/**`. Examples are not auto-run — sample
output blocks are filled in by the contributor during local verification.
