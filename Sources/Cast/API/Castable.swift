@attached(member, names: named(castSchema), named(init))
@attached(extension, conformances: Castable, Decodable)
public macro Castable() = #externalMacro(module: "CastMacros", type: "CastableMacro")
