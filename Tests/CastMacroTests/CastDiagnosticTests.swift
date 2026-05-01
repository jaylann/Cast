@testable import CastMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@Suite("CastableMacro Diagnostics")
struct CastDiagnosticTests {
    @Test("@Castable on class emits requiresStruct")
    func requiresStruct() {
        assertMacroExpansion(
            """
            @Castable
            class Bad {}
            """,
            expandedSource: """
            class Bad {}
            """,
            diagnostics: [
                DiagnosticSpec(message: CastableDiagnostic.requiresStruct.message, line: 1, column: 1)
            ],
            macros: testMacros
        )
    }

    @Test("@CastRange on String emits rangeOnString")
    func rangeOnString() {
        assertMacroExpansion(
            """
            @Castable
            struct Bad {
                @CastRange(1...10) var name: String = ""
            }
            """,
            expandedSource: """
            struct Bad {
                @CastRange(1...10) var name: String = ""
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: CastableDiagnostic.rangeOnString.message, line: 3, column: 5)
            ],
            macros: testMacros
        )
    }

    @Test("@MaxLength on Int emits lengthOnNumeric")
    func lengthOnNumeric() {
        assertMacroExpansion(
            """
            @Castable
            struct Bad {
                @MaxLength(10) var count: Int = 0
            }
            """,
            expandedSource: """
            struct Bad {
                @MaxLength(10) var count: Int = 0
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: CastableDiagnostic.lengthOnNumeric.message, line: 3, column: 5)
            ],
            macros: testMacros
        )
    }

    @Test("@MaxCount on non-Array emits countOnNonArray")
    func countOnNonArray() {
        assertMacroExpansion(
            """
            @Castable
            struct Bad {
                @MaxCount(5) var name: String = ""
            }
            """,
            expandedSource: """
            struct Bad {
                @MaxCount(5) var name: String = ""
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: CastableDiagnostic.countOnNonArray.message, line: 3, column: 5)
            ],
            macros: testMacros
        )
    }

    @Test("@CastRange(10...5) emits invertedRange")
    func invertedRange() {
        assertMacroExpansion(
            """
            @Castable
            struct Bad {
                @CastRange(10...5) var rating: Int = 0
            }
            """,
            expandedSource: """
            struct Bad {
                @CastRange(10...5) var rating: Int = 0
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: CastableDiagnostic.invertedRange.message, line: 3, column: 5)
            ],
            macros: testMacros
        )
    }

    @Test("@MinLength(100) @MaxLength(50) emits conflictingLengths")
    func conflictingLengths() {
        assertMacroExpansion(
            """
            @Castable
            struct Bad {
                @MinLength(100) @MaxLength(50) var name: String = ""
            }
            """,
            expandedSource: """
            struct Bad {
                @MinLength(100) @MaxLength(50) var name: String = ""
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: CastableDiagnostic.conflictingLengths.message, line: 3, column: 21)
            ],
            macros: testMacros
        )
    }

    @Test("@Pattern on Int emits patternOnNonString")
    func patternOnNonString() {
        assertMacroExpansion(
            """
            @Castable
            struct Bad {
                @Pattern("[0-9]+") var count: Int = 0
            }
            """,
            expandedSource: """
            struct Bad {
                @Pattern("[0-9]+") var count: Int = 0
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: CastableDiagnostic.patternOnNonString.message, line: 3, column: 5)
            ],
            macros: testMacros
        )
    }

    @Test("@Precision on String emits precisionOnNonFloat")
    func precisionOnNonFloat() {
        assertMacroExpansion(
            """
            @Castable
            struct Bad {
                @Precision(2) var name: String = ""
            }
            """,
            expandedSource: """
            struct Bad {
                @Precision(2) var name: String = ""
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: CastableDiagnostic.precisionOnNonFloat.message, line: 3, column: 5)
            ],
            macros: testMacros
        )
    }

    @Test("Foundation Date field emits unknownNonPrimitiveType warning but expansion still succeeds")
    func unknownFoundationType() {
        let warning = CastableDiagnostic.unknownNonPrimitiveType(typeName: "Date")
        assertMacroExpansion(
            """
            @Castable
            struct Event {
                var when: Date
            }
            """,
            expandedSource: """
            struct Event {
                var when: Date

                static let castSchema: JSONSchema = .object(
                    properties: OrderedDictionary(dictionaryLiteral:
                        ("when", Date.castSchema)
                    ),
                    required: ["when"],
                    additionalProperties: .boolean(false)
                )

                init() {
                }

                struct PartiallyGenerated: Sendable, Decodable {
                    var when: Date.PartiallyGenerated?
                }
            }

            extension Event: Castable, Decodable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: warning.message, line: 3, column: 5, severity: .warning)
            ],
            macros: testMacros
        )
    }
}
