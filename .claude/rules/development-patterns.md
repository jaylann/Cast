---
paths:
  - "Sources/**/*.swift"
---

# Common Development Patterns

## Dependency Injection Pattern

All services use **protocol-based dependency injection** with **default implementations**:

```swift
// 1. Define protocol
protocol GrammarCompiling: Sendable {
    func compile(schema: JSONSchema) -> Grammar
}

// 2. Implement
struct GrammarCompiler: GrammarCompiling {
    func compile(schema: JSONSchema) -> Grammar {
        // Implementation
    }
}

// 3. Inject with defaults
actor CastModel {
    private let grammarCompiler: GrammarCompiling

    init(grammarCompiler: GrammarCompiling = GrammarCompiler()) {
        self.grammarCompiler = grammarCompiler
    }
}

// 4. Testing with mocks
let mock = MockGrammarCompiler()
let model = CastModel(grammarCompiler: mock)
```

## Adding a New Property Wrapper Constraint

1. Define the property wrapper in `Sources/Cast/API/PropertyWrappers/`
2. Add constraint metadata to `Sources/Cast/Schema/ConstraintMetadata.swift`
3. Update grammar compiler to handle the new constraint
4. Update macro validation in `Sources/CastMacros/` to check type compatibility
5. Add macro expansion test in `Tests/CastMacroTests/`
6. Add runtime test in `Tests/CastTests/`

## Adding Support for a New Swift Type

1. Update `JSONSchemaGenerator` to map the Swift type to JSON Schema
2. Update grammar rules for the new type's token patterns
3. Update constrained sampler to handle the new type's state machine
4. Add tests for schema generation, grammar compilation, and end-to-end sampling
