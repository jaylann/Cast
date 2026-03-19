# Swift Best Practices

## Type Safety
- Avoid force unwraps (`!`), force tries (`try!`), and force casts (`as!`)
- `guard let` / `if let` for optionals
- `Result` or throwing functions over optional returns for fallible operations
- `some` for opaque types, `any` for existentials — use correctly

## Value Semantics
- Default to `struct` and `enum`. `class` only for identity semantics.
- Properties are `let` unless mutation is required
- `Sendable` conformance on types crossing isolation boundaries

## Modern Swift
- `if`/`switch` expressions where they simplify code
- `\.self` key paths over closures when possible

## Public API Design (Library)
- All public types need `public init` — Swift does NOT auto-synthesize public memberwise init
- Use `@frozen` on public enums only when ABI stability is needed
- Default parameter values for convenience: `public func cast(_ prompt: String, config: CastConfig = .default)`
- Mark implementation details `internal` or `private` — minimize public surface area
- Use `@available` for APIs that depend on specific platform versions

See `concurrency.md` for isolation and async patterns.

## Gotchas

### Regex
- Swift regex: lookbehind (`(?<!...)`) not supported — use alternatives
- NSRegularExpression uses ICU regex: `\uHHHH` not `\u{HHHH}`

### SPM
- `public struct` with `public var` does NOT auto-synthesize `public init` — must add explicit `public init` for cross-module construction
- SPM macro targets require `import CompilerPluginSupport` in Package.swift

### Codable
- Non-private stored properties without matching CodingKeys and without defaults block auto-synthesis
