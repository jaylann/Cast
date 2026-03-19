---
paths:
  - "Sources/CastMacros/**/*.swift"
  - "Tests/CastMacroTests/**/*.swift"
---

# Swift Macro Development

## Architecture

The `@Castable` macro is an **attached member macro** and **extension macro**:
- Inspects the struct's properties at compile time
- Reads property wrapper annotations (@MaxLength, @Range, etc.)
- Generates a static `_castSchema` property containing the JSON Schema and grammar rules
- Generates `Castable` protocol conformance

## SwiftSyntax Patterns

### Navigating the Syntax Tree
```swift
guard let structDecl = declaration.as(StructDeclSyntax.self) else {
    throw MacroError.notAStruct
}

for member in structDecl.memberBlock.members {
    guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }
    // Process each property
}
```

### Reading Attributes (Property Wrappers)
```swift
for attribute in varDecl.attributes {
    guard let attr = attribute.as(AttributeSyntax.self),
          let identifier = attr.attributeName.as(IdentifierTypeSyntax.self) else { continue }

    switch identifier.name.text {
    case "MaxLength":
        // Extract argument value
    case "Range":
        // Extract range bounds
    default: break
    }
}
```

### Emitting Diagnostics
```swift
context.diagnose(Diagnostic(
    node: attribute,
    message: CastDiagnostic.invalidAnnotation(
        "@Range cannot be applied to String properties"
    )
))
```

## Testing Macros

Always test both:
1. **Happy path** — correct expansion for valid input
2. **Diagnostics** — correct error messages for invalid input

```swift
assertMacroExpansion(
    source,
    expandedSource: expected,
    diagnostics: [
        DiagnosticSpec(message: "@Range cannot apply to String", line: 3, column: 5)
    ],
    macros: macros
)
```

## Common Pitfalls

- `TokenSyntax.text` includes backticks for escaped identifiers — use `trimmedDescription` for clean names
- Trivia (whitespace, comments) is part of the syntax tree — use `trimmed` versions
- Macro expansion tests are string-based — whitespace differences cause failures
- `@main` entry point in `CastMacroPlugin.swift` must list ALL macros in `providingMacros`
- Type resolution is limited in macros — you see syntax, not semantic types. Cannot resolve typealiases.
