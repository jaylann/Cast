/// Generates a JSON Schema and `Decodable` conformance for a struct, making it
/// usable as the output type of ``CastModel/cast(_:as:system:config:didGenerate:)-1jybk``.
///
/// Expands to a static `castSchema` derived from the stored properties (and any
/// Cast property wrappers like `@MaxLength`, `@CastRange`, `@OneOf`) plus a
/// matching `init(from:)`. The struct must be composed of `Castable` fields.
///
/// ```swift
/// @Castable
/// struct Recipe {
///     @MaxLength(80) var title: String
///     @MinCount(1) var ingredients: [String]
/// }
/// ```
///
/// ## Supported field types
///
/// - Primitives: `String`, `Bool`, `Int`/`UInt` and their sized variants,
///   `Double`, `Float`.
/// - Arrays of primitives or other `@Castable` types.
/// - Other `@Castable` types (nested structurally).
/// - `Optional` of any of the above.
///
/// Fields whose declared type is *neither* a known primitive *nor* another
/// `@Castable` struct (for example `Date`, `URL`, raw enums, custom types)
/// are projected into the synthesized `PartiallyGenerated` mirror as
/// `<TypeName>.PartiallyGenerated?`. Compilation will fail with an
/// "unknown member `PartiallyGenerated`" error unless the type itself
/// declares one. If you need to embed such a type, wrap it in a tiny
/// `@Castable` struct with a single field, or pre-convert to a supported
/// primitive (e.g. ISO-8601 `String` for dates) before generation.
@attached(
    member,
    names: named(castSchema), named(init), named(PartiallyGenerated)
)
@attached(extension, conformances: Castable, Decodable)
public macro Castable() = #externalMacro(module: "CastMacros", type: "CastableMacro")
