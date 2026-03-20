import Foundation
import Testing
import JSONSchema
import Collections

@testable import Cast

@Suite("JSONSchema.excluding")
struct SchemaExcludingTests {

    @Test("excluding removes fields from properties")
    func removesFields() throws {
        let schema = JSONSchema.object(
            properties: OrderedDictionary(dictionaryLiteral:
                ("name", JSONSchema.string()),
                ("age", JSONSchema.integer()),
                ("email", JSONSchema.string())
            ),
            required: ["name", "age", "email"],
            additionalProperties: .boolean(false)
        )

        let reduced = schema.excluding(fields: ["age"])
        let json = try schemaDict(reduced)
        let props = json["properties"] as? [String: Any]

        #expect(props?["name"] != nil)
        #expect(props?["email"] != nil)
        #expect(props?["age"] == nil)
    }

    @Test("excluding removes fields from required array")
    func removesFromRequired() throws {
        let schema = JSONSchema.object(
            properties: OrderedDictionary(dictionaryLiteral:
                ("name", JSONSchema.string()),
                ("age", JSONSchema.integer()),
                ("email", JSONSchema.string())
            ),
            required: ["name", "age", "email"],
            additionalProperties: .boolean(false)
        )

        let reduced = schema.excluding(fields: ["age"])
        let json = try schemaDict(reduced)
        let required = json["required"] as? [String] ?? []

        #expect(required.contains("name"))
        #expect(required.contains("email"))
        #expect(!required.contains("age"))
    }

    @Test("excluding multiple fields")
    func multipleFields() throws {
        let schema = JSONSchema.object(
            properties: OrderedDictionary(dictionaryLiteral:
                ("a", JSONSchema.string()),
                ("b", JSONSchema.integer()),
                ("c", JSONSchema.number()),
                ("d", JSONSchema.boolean())
            ),
            required: ["a", "b", "c", "d"],
            additionalProperties: .boolean(false)
        )

        let reduced = schema.excluding(fields: ["b", "d"])
        let json = try schemaDict(reduced)
        let props = json["properties"] as? [String: Any]

        #expect(props?.count == 2)
        #expect(props?["a"] != nil)
        #expect(props?["c"] != nil)
        #expect(props?["b"] == nil)
        #expect(props?["d"] == nil)
    }

    @Test("excluding empty set returns equivalent schema")
    func emptyExclusion() throws {
        let schema = JSONSchema.object(
            properties: OrderedDictionary(dictionaryLiteral:
                ("name", JSONSchema.string()),
                ("age", JSONSchema.integer())
            ),
            required: ["name", "age"]
        )

        let reduced = schema.excluding(fields: [])
        let json = try schemaDict(reduced)
        let props = json["properties"] as? [String: Any]

        #expect(props?.count == 2)
    }

    @Test("excluding preserves field constraints")
    func preservesConstraints() throws {
        let schema = JSONSchema.object(
            properties: OrderedDictionary(dictionaryLiteral:
                ("title", JSONSchema.string(maxLength: 100)),
                ("rating", JSONSchema.integer(minimum: 1, maximum: 10)),
                ("extra", JSONSchema.string())
            ),
            required: ["title", "rating", "extra"],
            additionalProperties: .boolean(false)
        )

        let reduced = schema.excluding(fields: ["extra"])
        let json = try schemaDict(reduced)
        let props = json["properties"] as? [String: Any] ?? [:]

        let title = props["title"] as? [String: Any]
        #expect(title?["maxLength"] as? Int == 100)

        let rating = props["rating"] as? [String: Any]
        #expect(rating?["minimum"] as? Int == 1)
        #expect(rating?["maximum"] as? Int == 10)
    }

    @Test("excluding all required fields removes required key")
    func allRequiredExcluded() throws {
        let schema = JSONSchema.object(
            properties: OrderedDictionary(dictionaryLiteral:
                ("a", JSONSchema.string()),
                ("b", JSONSchema.string())
            ),
            required: ["a", "b"]
        )

        let reduced = schema.excluding(fields: ["a", "b"])
        let json = try schemaDict(reduced)

        #expect(json["required"] == nil || (json["required"] as? [String])?.isEmpty == true)
    }

    @Test("excluding nonexistent fields is no-op")
    func nonexistentFields() throws {
        let schema = JSONSchema.object(
            properties: OrderedDictionary(dictionaryLiteral:
                ("name", JSONSchema.string())
            ),
            required: ["name"]
        )

        let reduced = schema.excluding(fields: ["doesNotExist"])
        let json = try schemaDict(reduced)
        let props = json["properties"] as? [String: Any]

        #expect(props?["name"] != nil)
    }

    @Test("excluding works with enum fields")
    func enumFields() throws {
        let schema = JSONSchema.object(
            properties: OrderedDictionary(dictionaryLiteral:
                ("status", JSONSchema.enum(values: [.string("active"), .string("inactive")])),
                ("name", JSONSchema.string())
            ),
            required: ["status", "name"]
        )

        let reduced = schema.excluding(fields: ["status"])
        let json = try schemaDict(reduced)
        let props = json["properties"] as? [String: Any]

        #expect(props?["status"] == nil)
        #expect(props?["name"] != nil)
    }

    // MARK: - Helpers

    private func schemaDict(_ schema: JSONSchema) throws -> [String: Any] {
        let data = try JSONEncoder().encode(schema)
        let sanitized = String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: "__[0-9]+__", with: "", options: .regularExpression)
        guard let jsonData = sanitized.data(using: .utf8),
              let dict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw TestError.invalidSchema
        }
        return dict
    }

    private enum TestError: Error {
        case invalidSchema
    }
}
