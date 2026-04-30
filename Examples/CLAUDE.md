# Examples

Runnable demonstrations of Cast's public API. Each example is a self-contained Swift executable that builds against the parent package.

## Structure

```
Examples/
  Package.swift                           # references parent via .package(path: "..")
  Sources/
    HelloCast/main.swift                  # one example per directory
    PropertyWrappersTour/main.swift
    NestedTypes/main.swift
    …
```

`Package.swift` declares each example as an `executableTarget`; building `Examples/` runs `swift build` against all of them simultaneously.

## Adding a new example

1. **Create `Sources/<Name>/main.swift`.** First line *must* be a single-line comment in this exact form:
   ```swift
   // What this shows: <one-sentence description>
   ```
   This becomes the DocC article description (see "DocC mirroring" below).
2. **Register the executable** in `Examples/Package.swift` under `targets:`:
   ```swift
   .executableTarget(name: "<Name>", dependencies: ["Cast"], path: "Sources/<Name>")
   ```
3. **Add a DocC topic entry** in `Sources/Cast/Cast.docc/Cast.md` under `## Topics` → `### Examples`:
   ```markdown
   - <doc:<Name>>
   ```
4. **Build to verify**: `cd Examples && swift build`. CI will do the same on push to `stage` (path-filtered to `Sources/Cast/**` or `Examples/**`).

The corresponding `Cast.docc/Examples/<Name>.md` article is **auto-generated** — don't write it by hand; the script overwrites it.

## DocC mirroring

`scripts/generate-example-docs.sh` reads each `Examples/Sources/<Name>/main.swift`, takes the first-line `// What this shows:` comment as the article description, and writes `Sources/Cast/Cast.docc/Examples/<Name>.md` with the source rendered as a Swift code block.

CI (`.github/workflows/docs.yml`) regenerates these articles before building DocC, so committed `.md` files can drift from source — but the *published* site never does. If you only edit `main.swift`, run the script locally to see the rendered article; otherwise a stale committed `.md` will look wrong locally but be correct online.

```bash
./scripts/generate-example-docs.sh
```

## CI behavior

- `examples.yml` builds (no run) on push to `stage` and on PRs to `stage`, path-filtered to `Sources/Cast/**`, `Examples/**`, and the workflow file itself.
- `docs.yml` regenerates articles + builds DocC + deploys to GitHub Pages on push to `main`.
- Examples are never *executed* in CI — they typically need a downloaded LLM model, which is too heavy + slow.

## Don'ts

- Don't depend on `Sources/MLXStructured` directly from an example — the public API surface is `import Cast`. Examples are also documentation; reaching past the public layer would mislead users.
- Don't commit a generated `Cast.docc/Examples/<Name>.md` divergent from `main.swift` and assume CI will fix it — it does, but local DocC preview won't until you re-run the script.
- Don't add examples that require interactive input (stdin prompts, file picks, etc.) — they break the "build only, no run" CI assumption and confuse readers.
