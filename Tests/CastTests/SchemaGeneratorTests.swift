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

private enum Sentiment: String, CastEnum {
    case positive, negative, neutral
}

private struct ConstrainedStruct: Codable, Castable {
    @MaxLength(100) var title: String = ""
    @MinLength(1) var name: String = ""
    @CastRange(1...10) var rating: Int = 0
    @MaxCount(5) var tags: [String] = []
    @MinCount(1) var items: [String] = []
    @OneOf(["USD", "EUR", "GBP"]) var currency: String = ""
    @Description("A brief summary") var summary: String = ""
    @Examples("Good", "Bad") var review: String = ""
}

private struct EnumFieldStruct: Castable {
    var sentiment: Sentiment = .positive
    var text: String = ""
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

    @Test("MaxLength constraint applied to schema")
    func maxLengthConstraint() throws {
        let schema = try SchemaGenerator.schema(for: ConstrainedStruct.self)
        let prop = try extractProperty(from: schema, named: "title")
        #expect(prop["type"] as? String == "string")
        #expect(prop["maxLength"] as? Int == 100)
    }

    @Test("MinLength constraint applied to schema")
    func minLengthConstraint() throws {
        let schema = try SchemaGenerator.schema(for: ConstrainedStruct.self)
        let prop = try extractProperty(from: schema, named: "name")
        #expect(prop["type"] as? String == "string")
        #expect(prop["minLength"] as? Int == 1)
    }

    @Test("CastRange constraint applied to integer schema")
    func rangeConstraint() throws {
        let schema = try SchemaGenerator.schema(for: ConstrainedStruct.self)
        let prop = try extractProperty(from: schema, named: "rating")
        #expect(prop["type"] as? String == "integer")
        #expect(prop["minimum"] as? Int == 1)
        #expect(prop["maximum"] as? Int == 10)
    }

    @Test("MaxCount constraint applied to array schema")
    func maxCountConstraint() throws {
        let schema = try SchemaGenerator.schema(for: ConstrainedStruct.self)
        let prop = try extractProperty(from: schema, named: "tags")
        #expect(prop["type"] as? String == "array")
        #expect(prop["maxItems"] as? Int == 5)
    }

    @Test("MinCount constraint applied to array schema")
    func minCountConstraint() throws {
        let schema = try SchemaGenerator.schema(for: ConstrainedStruct.self)
        let prop = try extractProperty(from: schema, named: "items")
        #expect(prop["type"] as? String == "array")
        #expect(prop["minItems"] as? Int == 1)
    }

    @Test("OneOf constraint produces enum schema")
    func oneOfConstraint() throws {
        let schema = try SchemaGenerator.schema(for: ConstrainedStruct.self)
        let prop = try extractProperty(from: schema, named: "currency")
        let enumValues = prop["enum"] as? [String]
        #expect(enumValues != nil)
        #expect(Set(enumValues!) == Set(["USD", "EUR", "GBP"]))
    }

    @Test("Description annotation extracted")
    func descriptionAnnotation() throws {
        let annotations = try SchemaGenerator.annotations(for: ConstrainedStruct.self)
        #expect(annotations["summary"]?.description == "A brief summary")
    }

    @Test("Examples annotation extracted")
    func examplesAnnotation() throws {
        let annotations = try SchemaGenerator.annotations(for: ConstrainedStruct.self)
        #expect(annotations["review"]?.examples == ["Good", "Bad"])
    }

    @Test("CastEnum field detected via CastSchemaProviding")
    func castEnumField() throws {
        let schema = try SchemaGenerator.schema(for: EnumFieldStruct.self)
        let prop = try extractProperty(from: schema, named: "sentiment")
        let enumValues = prop["enum"] as? [String]
        #expect(enumValues != nil)
        #expect(Set(enumValues!) == Set(["positive", "negative", "neutral"]))
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

/// Extract a named property's schema dict from an object schema.
/// Handles JSONSchema's __N__name ordering prefix format.
private func extractProperty(from schema: JSONSchema, named name: String) throws -> [String: Any] {
    let json = try jsonDict(schema)
    guard let props = json["properties"] as? [String: Any] else {
        throw TestError(message: "No properties in schema")
    }
    // Keys may be prefixed with __N__ for ordering
    for (key, value) in props {
        let cleanKey = key.replacingOccurrences(
            of: #"__\d+__"#, with: "", options: .regularExpression
        )
        if cleanKey == name, let dict = value as? [String: Any] {
            return dict
        }
    }
    throw TestError(message: "Property '\(name)' not found. Keys: \(props.keys)")
}

private struct TestError: Error {
    let message: String
}
