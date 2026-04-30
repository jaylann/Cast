@testable import CastMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

let testMacros: [String: any Macro.Type] = [
    "Castable": CastableMacro.self,
]

@Suite("CastableMacro Expansion")
struct CastMacroExpansionTests {
    @Test("simple struct with primitives")
    func simpleStruct() {
        assertMacroExpansion(
            """
            @Castable
            struct Review {
                var title: String = ""
                var rating: Int = 0
                var score: Double = 0.0
                var active: Bool = false
            }
            """,
            expandedSource: """
            struct Review {
                var title: String = ""
                var rating: Int = 0
                var score: Double = 0.0
                var active: Bool = false

                static let castSchema: JSONSchema = .object(
                    properties: OrderedDictionary(dictionaryLiteral:
                        ("title", .string()),
                        ("rating", .integer()),
                        ("score", .number()),
                        ("active", .boolean())
                    ),
                    required: ["title", "rating", "score", "active"],
                    additionalProperties: .boolean(false)
                )

                init() {
                }
            }

            extension Review: Castable, Decodable {
            }
            """,
            macros: testMacros
        )
    }

    @Test("struct with MaxLength and MinLength")
    func stringConstraints() {
        assertMacroExpansion(
            """
            @Castable
            struct Profile {
                @MaxLength(100) var name: String = ""
                @MinLength(1) var bio: String = ""
            }
            """,
            expandedSource: """
            struct Profile {
                @MaxLength(100) var name: String = ""
                @MinLength(1) var bio: String = ""

                static let castSchema: JSONSchema = .object(
                    properties: OrderedDictionary(dictionaryLiteral:
                        ("name", .string(maxLength: 100)),
                        ("bio", .string(minLength: 1))
                    ),
                    required: ["name", "bio"],
                    additionalProperties: .boolean(false)
                )

                init() {
                }
            }

            extension Profile: Castable, Decodable {
            }
            """,
            macros: testMacros
        )
    }

    @Test("struct with CastRange")
    func rangeConstraint() {
        assertMacroExpansion(
            """
            @Castable
            struct Rated {
                @CastRange(1...10) var rating: Int = 0
            }
            """,
            expandedSource: """
            struct Rated {
                @CastRange(1...10) var rating: Int = 0

                static let castSchema: JSONSchema = .object(
                    properties: OrderedDictionary(dictionaryLiteral:
                        ("rating", .integer(minimum: 1, maximum: 10))
                    ),
                    required: ["rating"],
                    additionalProperties: .boolean(false)
                )

                init() {
                }
            }

            extension Rated: Castable, Decodable {
            }
            """,
            macros: testMacros
        )
    }

    @Test("struct with array constraints")
    func arrayConstraints() {
        assertMacroExpansion(
            """
            @Castable
            struct Lists {
                @MaxCount(5) var tags: [String] = []
                @MinCount(1) var items: [Int] = []
            }
            """,
            expandedSource: """
            struct Lists {
                @MaxCount(5) var tags: [String] = []
                @MinCount(1) var items: [Int] = []

                static let castSchema: JSONSchema = .object(
                    properties: OrderedDictionary(dictionaryLiteral:
                        ("tags", .array(items: .string(), maxItems: 5)),
                        ("items", .array(items: .integer(), minItems: 1))
                    ),
                    required: ["tags", "items"],
                    additionalProperties: .boolean(false)
                )

                init() {
                }
            }

            extension Lists: Castable, Decodable {
            }
            """,
            macros: testMacros
        )
    }

    @Test("struct with optional field not in required")
    func optionalField() {
        assertMacroExpansion(
            """
            @Castable
            struct Opt {
                var name: String = ""
                var nickname: String? = nil
            }
            """,
            expandedSource: """
            struct Opt {
                var name: String = ""
                var nickname: String? = nil

                static let castSchema: JSONSchema = .object(
                    properties: OrderedDictionary(dictionaryLiteral:
                        ("name", .string()),
                        ("nickname", .string())
                    ),
                    required: ["name"],
                    additionalProperties: .boolean(false)
                )

                init() {
                }
            }

            extension Opt: Castable, Decodable {
            }
            """,
            macros: testMacros
        )
    }

    @Test("struct with nested Castable type")
    func nestedType() {
        assertMacroExpansion(
            """
            @Castable
            struct Article {
                var title: String = ""
                var author: Author = .init()
            }
            """,
            expandedSource: """
            struct Article {
                var title: String = ""
                var author: Author = .init()

                static let castSchema: JSONSchema = .object(
                    properties: OrderedDictionary(dictionaryLiteral:
                        ("title", .string()),
                        ("author", Author.castSchema)
                    ),
                    required: ["title", "author"],
                    additionalProperties: .boolean(false)
                )

                init() {
                }
            }

            extension Article: Castable, Decodable {
            }
            """,
            macros: testMacros
        )
    }

    @Test("struct with array of nested type")
    func nestedArrayType() {
        assertMacroExpansion(
            """
            @Castable
            struct Doc {
                var sections: [Section] = []
            }
            """,
            expandedSource: """
            struct Doc {
                var sections: [Section] = []

                static let castSchema: JSONSchema = .object(
                    properties: OrderedDictionary(dictionaryLiteral:
                        ("sections", .array(items: Section.castSchema))
                    ),
                    required: ["sections"],
                    additionalProperties: .boolean(false)
                )

                init() {
                }
            }

            extension Doc: Castable, Decodable {
            }
            """,
            macros: testMacros
        )
    }

    @Test("struct with OneOf wrapper")
    func oneOfWrapper() {
        assertMacroExpansion(
            """
            @Castable
            struct Currency {
                @OneOf(["USD", "EUR"]) var code: String = ""
            }
            """,
            expandedSource: """
            struct Currency {
                @OneOf(["USD", "EUR"]) var code: String = ""

                static let castSchema: JSONSchema = .object(
                    properties: OrderedDictionary(dictionaryLiteral:
                        ("code", .enum(values: ["USD", "EUR"].map { .string($0) }))
                    ),
                    required: ["code"],
                    additionalProperties: .boolean(false)
                )

                init() {
                }
            }

            extension Currency: Castable, Decodable {
            }
            """,
            macros: testMacros
        )
    }

    @Test("plugin registers CastableMacro")
    func pluginRegistered() {
        let plugin = CastMacroPlugin()
        #expect(plugin.providingMacros.count == 1)
    }
}
