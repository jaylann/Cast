import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct CastMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [CastableMacro.self]
}
