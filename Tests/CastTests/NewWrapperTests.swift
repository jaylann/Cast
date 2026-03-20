import Foundation
import JSONSchema
import Testing

@testable import Cast

fileprivate struct NewWrappersStruct {
    @Pattern("[a-z]+") var code: String = ""
    @Precision(2) var price: Double = 0.0
    @Count(3) var topPicks: [String] = []
    @Nullable var nickname: String = ""
    @DefaultValue("N/A") var company: String = ""
}

fileprivate struct CastableNewWrappers: Castable {
    @Pattern("[a-z]+") var code: String = ""
    @Precision(2) var price: Double = 0.0
    @Count(3) var picks: [String] = []
    @Nullable var nick: String = ""
    @DefaultValue("N/A") var company: String = ""
    init() {}
}

@Suite("NewPropertyWrappers")
struct NewWrapperTests {

    fileprivate let instance = NewWrappersStruct()

    // MARK: - Mirror constraint detection

    @Test("Pattern constraint readable via Mirror")
    func patternMirror() {
        let mirror = Mirror(reflecting: instance)
        let child = mirror.children.first { $0.label == "_code" }!
        let wrapper = child.value as! Pattern<String>
        #expect(wrapper.pattern == "[a-z]+")
    }

    @Test("Precision constraint readable via Mirror")
    func precisionMirror() {
        let mirror = Mirror(reflecting: instance)
        let child = mirror.children.first { $0.label == "_price" }!
        let wrapper = child.value as! Precision<Double>
        #expect(wrapper.precision == 2)
    }

    @Test("Count constraint readable via Mirror")
    func countMirror() {
        let mirror = Mirror(reflecting: instance)
        let child = mirror.children.first { $0.label == "_topPicks" }!
        let wrapper = child.value as! Count<[String]>
        #expect(wrapper.count == 3)
    }

    @Test("Nullable constraint readable via Mirror")
    func nullableMirror() {
        let mirror = Mirror(reflecting: instance)
        let child = mirror.children.first { $0.label == "_nickname" }!
        let wrapper = child.value as! Nullable<String>
        #expect(wrapper.isNullable == true)
    }

    @Test("DefaultValue constraint readable via Mirror")
    func defaultValueMirror() {
        let mirror = Mirror(reflecting: instance)
        let child = mirror.children.first { $0.label == "_company" }!
        let wrapper = child.value as! DefaultValue<String>
        #expect(wrapper.defaultValue == "N/A")
    }

    // MARK: - wrappedValue access

    @Test("wrappedValue read and write for new wrappers")
    func wrappedValueAccess() {
        var s = NewWrappersStruct()

        s.code = "abc"
        #expect(s.code == "abc")

        s.price = 19.99
        #expect(s.price == 19.99)

        s.topPicks = ["a", "b", "c"]
        #expect(s.topPicks == ["a", "b", "c"])

        s.nickname = "Jay"
        #expect(s.nickname == "Jay")

        s.company = "Acme"
        #expect(s.company == "Acme")
    }

    // MARK: - Codable round-trip

    @Test("Codable encode/decode round trip")
    func codableRoundTrip() throws {
        var original = NewWrappersStruct()
        original.code = "test"
        original.price = 42.5
        original.topPicks = ["x", "y"]
        original.nickname = "Nick"
        original.company = "Corp"

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(NewWrappersStruct.self, from: data)

        #expect(decoded.code == "test")
        #expect(decoded.price == 42.5)
        #expect(decoded.topPicks == ["x", "y"])
        #expect(decoded.nickname == "Nick")
        #expect(decoded.company == "Corp")
    }

    // MARK: - Schema generation

    @Test("Pattern produces schema with pattern field")
    func patternSchema() throws {
        let schema = try SchemaGenerator.schema(for: CastableNewWrappers.self)
        let prop = try extractProp(from: schema, named: "code")
        #expect(prop["type"] as? String == "string")
        #expect(prop["pattern"] as? String == "[a-z]+")
    }

    @Test("Precision produces schema with multipleOf field")
    func precisionSchema() throws {
        let schema = try SchemaGenerator.schema(for: CastableNewWrappers.self)
        let prop = try extractProp(from: schema, named: "price")
        #expect(prop["type"] as? String == "number")
        #expect(prop["multipleOf"] as? Double == 0.01)
    }

    @Test("Count produces schema with minItems and maxItems")
    func countSchema() throws {
        let schema = try SchemaGenerator.schema(for: CastableNewWrappers.self)
        let prop = try extractProp(from: schema, named: "picks")
        #expect(prop["type"] as? String == "array")
        #expect(prop["minItems"] as? Int == 3)
        #expect(prop["maxItems"] as? Int == 3)
    }

    @Test("Nullable removes field from required list")
    func nullableSchema() throws {
        let schema = try SchemaGenerator.schema(for: CastableNewWrappers.self)
        let json = try schemaDict(schema)
        let required = json["required"] as? [String] ?? []
        #expect(!required.contains("nick"))
        #expect(required.contains("code"))
    }

    @Test("nullableFields returns correct set")
    func nullableFieldsQuery() throws {
        let fields = try SchemaGenerator.nullableFields(for: CastableNewWrappers.self)
        #expect(fields.contains("nick"))
        #expect(!fields.contains("code"))
    }

    @Test("DefaultValue does not affect schema constraints")
    func defaultValueSchema() throws {
        let schema = try SchemaGenerator.schema(for: CastableNewWrappers.self)
        let prop = try extractProp(from: schema, named: "company")
        #expect(prop["type"] as? String == "string")
        #expect(prop["default"] == nil)
    }
}

extension NewWrappersStruct: Codable, Sendable {}

// MARK: - Helpers

private func schemaDict(_ schema: JSONSchema) throws -> [String: Any] {
    let data = try JSONEncoder().encode(schema)
    let obj = try JSONSerialization.jsonObject(with: data)
    return obj as? [String: Any] ?? [:]
}

private func extractProp(from schema: JSONSchema, named name: String) throws -> [String: Any] {
    let json = try schemaDict(schema)
    guard let props = json["properties"] as? [String: Any] else {
        throw ExtractError(message: "No properties in schema")
    }
    for (key, value) in props {
        let cleanKey = key.replacingOccurrences(
            of: #"__\d+__"#, with: "", options: .regularExpression
        )
        if cleanKey == name, let dict = value as? [String: Any] {
            return dict
        }
    }
    throw ExtractError(message: "Property '\(name)' not found. Keys: \(props.keys)")
}

private struct ExtractError: Error {
    let message: String
}
