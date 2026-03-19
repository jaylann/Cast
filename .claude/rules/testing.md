---
paths:
  - "Tests/**/*.swift"
---

# Testing Strategy

## Framework
- Prefer **Swift Testing** (`import Testing`) for new tests
- `@Test` for test functions, `@Suite` for grouping
- `#expect(condition)` for assertions, `#require(value)` for unwrapping
- Parameterized tests with `@Test(arguments:)` for multiple inputs

## Red-Green-Refactor (Recommended)
1. **Red** — Write a failing test defining desired behavior
2. **Green** — Write minimum code to make tests pass
3. **Refactor** — Clean up while keeping tests green

## Test Structure

```
Tests/
  CastTests/
    Schema/
      JSONSchemaGeneratorTests.swift
    Sampler/
      ConstrainedSamplerTests.swift
    Tokenizer/
      TokenizerLinkerTests.swift
    API/
      CastModelTests.swift
    Mocks/
      MockTokenizer.swift
      MockModel.swift
  CastMacroTests/
    CastableMacroTests.swift
    PropertyWrapperValidationTests.swift
```

## Running Tests

```bash
swift test                              # All tests
swift test --filter CastTests           # Library tests only
swift test --filter CastMacroTests      # Macro tests only
swift test --filter CastTests.SomeTest  # Specific test suite
```

Build/test commands require `dangerouslyDisableSandbox: true` due to SPM cache permissions.
Run in background (`run_in_background: true`) by default.

## Macro Testing

Use `SwiftSyntaxMacrosTestSupport` for macro expansion tests:

```swift
import SwiftSyntaxMacrosTestSupport
import Testing
@testable import CastMacros

@Suite("@Castable Macro")
struct CastableMacroTests {
    let macros: [String: Macro.Type] = [
        "Castable": CastableMacro.self,
    ]

    @Test("generates schema for simple struct")
    func simpleStruct() {
        assertMacroExpansion(
            """
            @Castable
            struct Review: Codable {
                var title: String
                var rating: Int
            }
            """,
            expandedSource: /* expected expansion */,
            macros: macros
        )
    }
}
```

## Naming
- `@Test("descriptive scenario")` display names
- Function names: `scenarioUnderTest()` or `whenCondition_expectsResult()`
- One behavior per test function

## Mock Implementations

Protocol-based mocks for all external dependencies:

```swift
struct MockTokenizer: Tokenizing {
    var vocabulary: [String: Int] = [:]
    func encode(_ text: String) -> [Int] { /* ... */ }
}
```

## Gotchas
- Swift Testing `.serialized` trait only serializes tests WITHIN a suite — different suites run concurrently
- Swift Testing files need explicit `import Foundation`
- `@Test(arguments:)` with inline tuple arrays can cause type-checker timeouts — use typed constants
- Macro tests require the macro type to be registered in a `macros` dictionary
