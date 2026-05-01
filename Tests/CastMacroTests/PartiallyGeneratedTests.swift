@testable import CastMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@Suite("CastableMacro PartiallyGenerated Synthesis")
struct PartiallyGeneratedExpansionTests {
    @Test("simple struct synthesizes Optional mirror")
    func simpleStruct() {
        assertMacroExpansion(
            """
            @Castable
            struct Foo {
                var a: String = ""
                var b: Int = 0
            }
            """,
            expandedSource: """
            struct Foo {
                var a: String = ""
                var b: Int = 0

                static let castSchema: JSONSchema = .object(
                    properties: OrderedDictionary(dictionaryLiteral:
                        ("a", .string()),
                        ("b", .integer())
                    ),
                    required: ["a", "b"],
                    additionalProperties: .boolean(false)
                )

                init() {
                }

                struct PartiallyGenerated: Sendable, Decodable {
                    var a: String?
                    var b: Int?
                }
            }

            extension Foo: Castable, Decodable {
            }
            """,
            macros: testMacros
        )
    }

    @Test("MaxLength wrapper decays to underlying String?")
    func maxLengthDecays() {
        assertMacroExpansion(
            """
            @Castable
            struct Foo {
                @MaxLength(80) var title: String = ""
            }
            """,
            expandedSource: """
            struct Foo {
                @MaxLength(80) var title: String = ""

                static let castSchema: JSONSchema = .object(
                    properties: OrderedDictionary(dictionaryLiteral:
                        ("title", .string(maxLength: 80))
                    ),
                    required: ["title"],
                    additionalProperties: .boolean(false)
                )

                init() {
                }

                struct PartiallyGenerated: Sendable, Decodable {
                    var title: String?
                }
            }

            extension Foo: Castable, Decodable {
            }
            """,
            macros: testMacros
        )
    }

    @Test("CastRange wrapper decays to underlying Int?")
    func castRangeDecays() {
        assertMacroExpansion(
            """
            @Castable
            struct Foo {
                @CastRange(1...10) var rating: Int = 0
            }
            """,
            expandedSource: """
            struct Foo {
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

                struct PartiallyGenerated: Sendable, Decodable {
                    var rating: Int?
                }
            }

            extension Foo: Castable, Decodable {
            }
            """,
            macros: testMacros
        )
    }

    @Test("nested @Castable type recurses to inner PartiallyGenerated")
    func nestedCastable() {
        assertMacroExpansion(
            """
            @Castable
            struct Outer {
                var inner: Inner = .init()
            }
            """,
            expandedSource: """
            struct Outer {
                var inner: Inner = .init()

                static let castSchema: JSONSchema = .object(
                    properties: OrderedDictionary(dictionaryLiteral:
                        ("inner", Inner.castSchema)
                    ),
                    required: ["inner"],
                    additionalProperties: .boolean(false)
                )

                init() {
                }

                struct PartiallyGenerated: Sendable, Decodable {
                    var inner: Inner.PartiallyGenerated?
                }
            }

            extension Outer: Castable, Decodable {
            }
            """,
            macros: testMacros
        )
    }

    @Test("primitive array stays primitive in partial")
    func primitiveArray() {
        assertMacroExpansion(
            """
            @Castable
            struct Foo {
                var tags: [String] = []
            }
            """,
            expandedSource: """
            struct Foo {
                var tags: [String] = []

                static let castSchema: JSONSchema = .object(
                    properties: OrderedDictionary(dictionaryLiteral:
                        ("tags", .array(items: .string()))
                    ),
                    required: ["tags"],
                    additionalProperties: .boolean(false)
                )

                init() {
                }

                struct PartiallyGenerated: Sendable, Decodable {
                    var tags: [String]?
                }
            }

            extension Foo: Castable, Decodable {
            }
            """,
            macros: testMacros
        )
    }

    @Test("Optional source field stays single-Optional in the partial mirror")
    func optionalFields() {
        assertMacroExpansion(
            """
            @Castable
            struct Foo {
                var nickname: String?
                var nested: Inner?
            }
            """,
            expandedSource: """
            struct Foo {
                var nickname: String?
                var nested: Inner?

                static let castSchema: JSONSchema = .object(
                    properties: OrderedDictionary(dictionaryLiteral:
                        ("nickname", .string()),
                        ("nested", Inner.castSchema)
                    ),
                    required: nil,
                    additionalProperties: .boolean(false)
                )

                init() {
                }

                struct PartiallyGenerated: Sendable, Decodable {
                    var nickname: String?
                    var nested: Inner.PartiallyGenerated?
                }
            }

            extension Foo: Castable, Decodable {
            }
            """,
            macros: testMacros
        )
    }

    @Test("array of nested @Castable recurses through element")
    func nestedArray() {
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

                struct PartiallyGenerated: Sendable, Decodable {
                    var sections: [Section.PartiallyGenerated]?
                }
            }

            extension Doc: Castable, Decodable {
            }
            """,
            macros: testMacros
        )
    }

    @Test("array of optional primitive unwraps element type")
    func arrayOfOptionalPrimitive() {
        // `[String?]` must not double-wrap into `[String??]` or
        // `[String?.PartiallyGenerated]?` — the element's trailing `?`
        // is dropped before the partial-projection lookup.
        assertMacroExpansion(
            """
            @Castable
            struct Foo {
                var tags: [String?] = []
            }
            """,
            expandedSource: """
            struct Foo {
                var tags: [String?] = []

                static let castSchema: JSONSchema = .object(
                    properties: OrderedDictionary(dictionaryLiteral:
                        ("tags", .array(items: .string()))
                    ),
                    required: ["tags"],
                    additionalProperties: .boolean(false)
                )

                init() {
                }

                struct PartiallyGenerated: Sendable, Decodable {
                    var tags: [String]?
                }
            }

            extension Foo: Castable, Decodable {
            }
            """,
            macros: testMacros
        )
    }
}
