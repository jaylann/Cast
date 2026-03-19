---
paths:
  - "Package.swift"
---

# Build & Tooling

## Claude Code Sandbox
- Build requires `dangerouslyDisableSandbox: true` due to SPM cache permissions
- `ENABLE_TOOL_SEARCH: true` in settings.json env prevents MCP tools from bloating context

## Build Commands

```bash
swift build                              # Build all targets
swift test                               # Run all tests
swift test --filter CastTests            # Run library tests only
swift test --filter CastMacroTests       # Run macro tests only
swift test --filter CastTests.SuiteName  # Run specific suite
swift package resolve                    # Resolve dependencies
swift package clean                      # Clean build artifacts
swift package update                     # Update dependencies
swift package show-dependencies          # Show dependency tree
```

## Formatting & Linting

- SwiftFormat (Lockwood) installed via brew: `swiftformat --quiet` in PostToolUse hooks
- SwiftLint `--fix --quiet` chains after SwiftFormat in hooks
- Config files: `.swiftformat` and `.swiftlint.yml` in project root

## Dependencies

- **mlx-swift** (`mlx-swift`): Core MLX framework — `MLX`, `MLXNN`
- **mlx-swift-lm** (`mlx-swift-lm`): LLM support — `MLXLLM`, `MLXLMCommon`
- **swift-syntax** (`swift-syntax` 600.x): Macro development — `SwiftSyntaxMacros`, `SwiftCompilerPlugin`

**Version pinning:** Use `.upToNextMinor(from:)` for MLX packages to prevent silent breaking changes. Use `from:` for SwiftSyntax (semver stable).

## Package Structure

```
Package.swift              # Package manifest
Sources/
  Cast/                    # Main library (.target)
  CastMacros/              # Macro plugin (.macro)
Tests/
  CastTests/               # Library tests (.testTarget)
  CastMacroTests/          # Macro tests (.testTarget)
```

## Macro Development Notes

- Macro targets compile as separate executables (compiler plugins)
- `swift build` compiles macros for the host platform, not the target platform
- Macro tests use `assertMacroExpansion` from `SwiftSyntaxMacrosTestSupport`
- Changes to macro code require rebuild before tests reflect changes
