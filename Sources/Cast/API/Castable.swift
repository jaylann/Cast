@attached(member, names: named(castSchema), named(init))
@attached(extension, conformances: Castable, Codable, Sendable)
public macro Castable() = #externalMacro(module: "CastMacros", type: "CastableMacro")
