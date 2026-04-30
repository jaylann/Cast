# Sources/CastMacros

Compiler plugin target for the `@Castable` macro. Runs at **build time** inside the Swift compiler — not at runtime.

## Files

- `CastMacroPlugin.swift` — plugin entry point. Registers macros so the compiler can find them. Add new macros to this list.
- `CastableMacro.swift` — main `@Castable` implementation. Reads the annotated struct's stored properties + their property-wrapper attributes and emits the JSON Schema + grammar skeleton.

## Macro patterns

- Receive a `MacroExpansionContext` and `AttributeSyntax` / `DeclSyntax` node from SwiftSyntax. Walk the AST to extract what you need.
- Emit code as `DeclSyntax(stringLiteral: ...)` — Swift parses the string back into syntax for you.
- Diagnose problems with `context.diagnose(...)` rather than throwing or silently failing. Diagnostics show up in Xcode and `swift build` output and let users fix issues at the point of macro use.
- For `@Castable`: read property wrappers (`@MaxLength`, `@Range`, `@Description`) by walking attribute lists on each `VariableDeclSyntax`. The wrapper drives the schema — wrappers without a matching code-gen path will silently no-op, so add them deliberately.

## Testing macros

Tests live in `Tests/CastMacroTests/`. Use `swift-syntax`'s `assertMacroExpansion` to compare expected vs actual expansion as text. The test framework runs macros in-process, so:
- Test failures often show as a textual diff — read the diff carefully; subtle whitespace and trailing-comma differences trip people up.
- If the macro emits diagnostics, the test asserts on those too (file/line/severity/message).
- Tests run as part of the regular `swift test` and pass on CI (they don't need MLX runtime — pure compile-time work).

## Cross-references

- The grammar that this macro emits is consumed by `Sources/Cast/Schema/` at runtime to build a `GrammarMatcher`.
- For SwiftSyntax patterns or build-tooling questions, see `.claude/rules/macro-development.md` and `build-tooling.md`.

## Don'ts

- Don't add runtime dependencies here — this target is a compiler plugin and ships *only* at build time. Anything heavy belongs in `Sources/Cast/`.
- Don't fork SwiftSyntax behavior; if you need a new helper, add it to a small extension here rather than reaching across targets.
