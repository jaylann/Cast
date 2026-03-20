import Foundation
import JSONSchema
import Testing

@testable import Cast

// MARK: - Test Structs

private struct SimpleStruct: Codable, Sendable {
    var name: String
    var age: Int
    var score: Double
    var active: Bool
}

private struct OptionalStruct: Codable, Sendable {
    var name: String
    var nickname: String?
}

private struct NestedStruct: Codable, Sendable {
    var inner: SimpleStruct
    var label: String
}

private struct ArrayStruct: Codable, Sendable {
    var tags: [String]
    var scores: [Int]
}

private struct FloatStruct: Codable, Sendable {
    var value: Float
}

// MARK: - ZeroSchemaDecoder Tests

@Suite("ZeroSchemaDecoder")
struct ZeroSchemaDecoderTests {

    @Test("Simple struct decodes correct field types")
    func simpleStruct() throws {
        let info = try ZeroSchemaDecoder.decode(SimpleStruct.self)

        #expect(info.fields.count == 4)

        let kindMap = Dictionary(uniqueKeysWithValues: info.fields.map { ($0.name, $0.kind) })
        #expect(kindMap["name"] == .string)
        #expect(kindMap["age"] == .integer)
        #expect(kindMap["score"] == .number)
        #expect(kindMap["active"] == .boolean)

        #expect(info.required.count == 4)
        #expect(info.required.contains("name"))
        #expect(info.required.contains("age"))
        #expect(info.required.contains("score"))
        #expect(info.required.contains("active"))
    }

    @Test("Optional field is not in required list")
    func optionalField() throws {
        let info = try ZeroSchemaDecoder.decode(OptionalStruct.self)

        #expect(info.fields.count == 2)
        #expect(info.required == ["name"])

        let kindMap = Dictionary(uniqueKeysWithValues: info.fields.map { ($0.name, $0.kind) })
        #expect(kindMap["name"] == .string)
        #expect(kindMap["nickname"] == .string)
    }

    @Test("Array fields produce array schema with correct items")
    func arrayFields() throws {
        let info = try ZeroSchemaDecoder.decode(ArrayStruct.self)

        #expect(info.fields.count == 2)

        let kindMap = Dictionary(uniqueKeysWithValues: info.fields.map { ($0.name, $0.kind) })
        #expect(kindMap["tags"] == .array(element: .string))
        #expect(kindMap["scores"] == .array(element: .integer))
    }

    @Test("Nested struct produces recursive object schema")
    func nestedStruct() throws {
        let info = try ZeroSchemaDecoder.decode(NestedStruct.self)

        #expect(info.fields.count == 2)

        let kindMap = Dictionary(uniqueKeysWithValues: info.fields.map { ($0.name, $0.kind) })
        #expect(kindMap["label"] == .string)
        #expect(kindMap["inner"] == .object)

        // Verify nested schema serializes correctly
        let innerField = info.fields.first { $0.name == "inner" }!
        let json = try jsonDict(innerField.schema)
        #expect(json["type"] as? String == "object")
        // Property keys include ordering prefixes (__N__name) from JSONSchema encoding
        let props = json["properties"] as? [String: Any]
        #expect(props != nil)
        let propKeys = props?.keys.joined(separator: ",") ?? ""
        #expect(propKeys.contains("name"))
        #expect(propKeys.contains("age"))
    }

    @Test("Bool field produces boolean schema")
    func boolField() throws {
        let info = try ZeroSchemaDecoder.decode(SimpleStruct.self)
        let kindMap = Dictionary(uniqueKeysWithValues: info.fields.map { ($0.name, $0.kind) })
        #expect(kindMap["active"] == .boolean)
    }

    @Test("Float field produces number schema")
    func floatField() throws {
        let info = try ZeroSchemaDecoder.decode(FloatStruct.self)
        let kindMap = Dictionary(uniqueKeysWithValues: info.fields.map { ($0.name, $0.kind) })
        #expect(kindMap["value"] == .number)
    }

    @Test("Zero instance has correct default values")
    func zeroValues() throws {
        let info = try ZeroSchemaDecoder.decode(SimpleStruct.self)
        let zero = info.zeroInstance as? SimpleStruct
        #expect(zero != nil)
        #expect(zero?.name == "")
        #expect(zero?.age == 0)
        #expect(zero?.score == 0)
        #expect(zero?.active == false)
    }
}

// MARK: - SchemaGenerator Tests

@Suite("SchemaGenerator")
struct SchemaGeneratorTests {

    @Test("schema() returns object schema with correct properties")
    func schemaGeneration() throws {
        let schema = try SchemaGenerator.schema(for: SimpleStruct.self)
        let json = try jsonDict(schema)

        #expect(json["type"] as? String == "object")

        let required = json["required"] as? [String]
        #expect(required?.count == 4)
        #expect(required?.contains("name") == true)

        let props = json["properties"] as? [String: Any]
        #expect(props != nil)
        #expect(props?.count == 4)
    }

    @Test("schema() caches results - second call returns same instance")
    func caching() throws {
        let first = try SchemaGenerator.schema(for: SimpleStruct.self)
        let second = try SchemaGenerator.schema(for: SimpleStruct.self)
        #expect(first === second)
    }

    @Test("additionalProperties is false")
    func noAdditionalProperties() throws {
        let schema = try SchemaGenerator.schema(for: SimpleStruct.self)
        let json = try jsonDict(schema)
        #expect(json["additionalProperties"] as? Bool == false)
    }
}

// MARK: - Helpers

/// Encode a JSONSchema to a dictionary for assertion purposes.
private func jsonDict(_ schema: JSONSchema) throws -> [String: Any] {
    let encoder = JSONEncoder()
    let data = try encoder.encode(schema)
    let obj = try JSONSerialization.jsonObject(with: data)
    return obj as? [String: Any] ?? [:]
}
