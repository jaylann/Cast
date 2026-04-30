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
@attached(member, names: named(castSchema), named(init))
@attached(extension, conformances: Castable, Decodable)
public macro Castable() = #externalMacro(module: "CastMacros", type: "CastableMacro")
