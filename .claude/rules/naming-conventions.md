---
paths:
  - "Sources/**/*.swift"
---

# Naming Conventions

## Class/Struct Naming

| Suffix | Purpose | Examples |
|--------|---------|----------|
| `*Engine` | Core processing components with complex logic | `GrammarEngine`, `SamplingEngine` |
| `*Processor` | Data transformation steps in a pipeline | `LogitsProcessor`, `SchemaProcessor` |
| `*Builder` | Object builders — construct complex objects step by step | `GrammarBuilder`, `PromptBuilder` |
| `*Cache` | Caching and memoization | `TokenizerCache`, `GrammarCache` |
| `*Provider` | Data/configuration providers | `ModelProvider`, `TokenizerProvider` |
| `*Compiler` | Transformation from one representation to another | `GrammarCompiler`, `SchemaCompiler` |

## Protocol Naming

- **Use `-ing` suffix** for protocols: `GrammarCompiling`, `TokenMasking`, `ModelLoading`
- **Never use `*Protocol` suffix** — redundant and non-idiomatic Swift
- Protocol names describe capability: `Sendable`, `Codable`, `Castable`

## File Organization

- One primary type per file, file named after the type
- Extensions in separate files when substantial: `CastModel+Generation.swift`
- Test files mirror source structure in `Tests/`
