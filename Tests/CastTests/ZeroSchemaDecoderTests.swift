@testable import Cast
import Collections
import Foundation
import JSONSchema
import Testing

// MARK: - Test Fixtures

private struct AllPrimitives: Decodable, Sendable {
    var b: Bool = false
    var s: String = ""
    var d: Double = 0
    var f: Float = 0
    var i: Int = 0
    var i8: Int8 = 0
    var i16: Int16 = 0
    var i32: Int32 = 0
    var i64: Int64 = 0
    var u: UInt = 0
    var u8: UInt8 = 0
    var u16: UInt16 = 0
    var u32: UInt32 = 0
    var u64: UInt64 = 0
}

private struct RequiredAndOptional: Decodable, Sendable {
    var a: Int = 0
    var b: String?
}

private struct PrimitiveArrays: Decodable, Sendable {
    var ss: [String] = []
    var ii: [Int] = []
    var dd: [Double] = []
    var bb: [Bool] = []
}

private struct InnerArrayItem: Decodable, Sendable {
    var x: Int = 0
}

private struct ArrayOfNested: Decodable, Sendable {
    var items: [InnerArrayItem] = []
}

@Castable
private struct InnerNest {
    var x: Int = 0
}

@Castable
private struct OuterNest {
    var inner: InnerNest = .init()
}

private enum SwatchColor: String, CastEnum {
    case red, blue
}

private struct ColorHolder: Decodable, Sendable {
    var color: SwatchColor = .red
}

@Castable
private struct WithMaxLen {
    @MaxLength(10) var title: String = ""
}

private enum CustomKind: String, Decodable, Sendable, CaseIterable, CastSchemaProviding, _FirstCaseProvider {
    case alpha, beta
    static var castSchema: JSONSchema {
        .enum(values: [.string("ALPHA"), .string("BETA")])
    }

    static var _firstCaseAny: Any {
        CustomKind.alpha
    }
}

private struct CustomKindHolder: Decodable, Sendable {
    var kind: CustomKind = .alpha
}

private struct FieldOrder: Decodable, Sendable {
    var z: Int = 0
    var a: String = ""
    var m: Bool = false
}

private enum Direction: String, Decodable, Sendable, CaseIterable, _FirstCaseProvider {
    case north, south
    static var _firstCaseAny: Any {
        Direction.north
    }
}

private struct SimpleForRoundTrip: Decodable, Sendable {
    var name: String = ""
    var count: Int = 0
}

// MARK: - Suite

@Suite("ZeroSchemaDecoder")
struct ZeroSchemaDecoderDirectTests {
    @Test("Primitives produce matching SchemaKinds")
    func primitivesProduceMatchingSchemaKinds() throws {
        let info = try ZeroSchemaDecoder.decode(AllPrimitives.self)
        let kinds = Dictionary(uniqueKeysWithValues: info.fields.map { ($0.name, $0.kind) })

        #expect(kinds["b"] == .boolean)
        #expect(kinds["s"] == .string)
        #expect(kinds["d"] == .number)
        #expect(kinds["f"] == .number)
        #expect(kinds["i"] == .integer)
        #expect(kinds["i8"] == .integer)
        #expect(kinds["i16"] == .integer)
        #expect(kinds["i32"] == .integer)
        #expect(kinds["i64"] == .integer)
        #expect(kinds["u"] == .integer)
        #expect(kinds["u8"] == .integer)
        #expect(kinds["u16"] == .integer)
        #expect(kinds["u32"] == .integer)
        #expect(kinds["u64"] == .integer)
    }

    @Test("Required vs optional tracked separately")
    func requiredVsOptional() throws {
        let info = try ZeroSchemaDecoder.decode(RequiredAndOptional.self)
        #expect(info.required == ["a"])
        #expect(info.fields.count == 2)
    }

    @Test("Primitive arrays produce array schema with element kinds")
    func primitiveArrays() throws {
        let info = try ZeroSchemaDecoder.decode(PrimitiveArrays.self)
        let kinds = Dictionary(uniqueKeysWithValues: info.fields.map { ($0.name, $0.kind) })

        #expect(kinds["ss"] == .array(element: .string))
        #expect(kinds["ii"] == .array(element: .integer))
        #expect(kinds["dd"] == .array(element: .number))
        #expect(kinds["bb"] == .array(element: .boolean))
    }

    @Test("Array of nested structs yields object items schema")
    func arrayOfNestedStructs() throws {
        let info = try ZeroSchemaDecoder.decode(ArrayOfNested.self)
        let field = try #require(info.fields.first { $0.name == "items" })
        #expect(field.kind == .array(element: .object))

        let data = try JSONEncoder().encode(field.schema)
        let json = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let items = try #require(json["items"] as? [String: Any])
        let props = try #require(items["properties"] as? [String: Any])
        let propKeys = props.keys.joined(separator: ",")
        #expect(propKeys.contains("x"))
    }

    @Test("Nested @Castable object yields object kind with inner properties")
    func nestedCastableObject() throws {
        let info = try ZeroSchemaDecoder.decode(OuterNest.self)
        let field = try #require(info.fields.first { $0.name == "inner" })
        #expect(field.kind == .object)

        let data = try JSONEncoder().encode(field.schema)
        let json = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(json["type"] as? String == "object")
        let props = try #require(json["properties"] as? [String: Any])
        let propKeys = props.keys.joined(separator: ",")
        #expect(propKeys.contains("x"))
    }

    @Test("Enum via CastEnum decodes as enumeration with first case zero")
    func enumViaCastEnum() throws {
        let info = try ZeroSchemaDecoder.decode(ColorHolder.self)
        let field = try #require(info.fields.first { $0.name == "color" })
        #expect(field.kind == .enumeration)

        let zero = try #require(info.zeroInstance as? ColorHolder)
        #expect(zero.color == .red)
    }

    @Test("Zero instance populates primitives with their zero values")
    func zeroInstancePopulatesPrimitives() throws {
        let info = try ZeroSchemaDecoder.decode(AllPrimitives.self)
        let zero = try #require(info.zeroInstance as? AllPrimitives)

        #expect(zero.b == false)
        #expect(zero.s == "")
        #expect(zero.d == 0)
        #expect(zero.f == 0)
        #expect(zero.i == 0)
        #expect(zero.i8 == 0)
        #expect(zero.u == 0)
        #expect(zero.u64 == 0)
    }

    @Test("Property wrapper field short-circuits to wrapped value's kind")
    func propertyWrapperShortCircuit() throws {
        let info = try ZeroSchemaDecoder.decode(WithMaxLen.self)
        let field = try #require(info.fields.first { $0.name == "title" })
        #expect(field.kind == .string)
    }

    @Test("CastSchemaProviding override is used over structural decoding")
    func castSchemaProvidingOverride() throws {
        let info = try ZeroSchemaDecoder.decode(CustomKindHolder.self)
        let field = try #require(info.fields.first { $0.name == "kind" })
        #expect(field.kind == .enumeration)

        let data = try JSONEncoder().encode(field.schema)
        let raw = String(decoding: data, as: UTF8.self)
        #expect(raw.contains("ALPHA"))
        #expect(raw.contains("BETA"))
    }

    @Test("Field order matches Decodable init traversal, not alphabetical")
    func fieldOrderPreserved() throws {
        let info = try ZeroSchemaDecoder.decode(FieldOrder.self)
        #expect(info.fields.map(\.name) == ["z", "a", "m"])
    }

    @Test("_FirstCaseProvider returns the declared first case")
    func firstCaseProviderProtocolReturnsFirstCase() {
        let any = Direction._firstCaseAny
        #expect(any as? Direction == .north)
    }

    @Test("Each SchemaField.schema round-trips through JSONEncoder")
    func schemaInfoExposesEncodedSchema() throws {
        let info = try ZeroSchemaDecoder.decode(SimpleForRoundTrip.self)
        #expect(info.fields.count == 2)

        let encoder = JSONEncoder()
        for field in info.fields {
            let data = try encoder.encode(field.schema)
            #expect(!data.isEmpty)
            let obj = try JSONSerialization.jsonObject(with: data)
            #expect(obj is [String: Any])
        }
    }
}
