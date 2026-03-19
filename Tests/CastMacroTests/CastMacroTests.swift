import SwiftSyntaxMacrosTestSupport
import Testing

@testable import CastMacros

@Suite("CastMacros")
struct CastMacroTests {
    @Test("plugin registers no macros initially")
    func pluginEmpty() {
        let plugin = CastMacroPlugin()
        #expect(plugin.providingMacros.isEmpty)
    }
}
