@testable import Cast
import Collections
import Foundation
import JSONSchema
import Testing

@Suite("JSONSchema.excluding")
struct SchemaExcludingTests {
    @Test("excluding removes fields from properties")
    func removesFields() throws {
        let schema = JSONSchema.object(
            properties: OrderedDictionary(
                dictionaryLiteral:
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
            properties: OrderedDictionary(
                dictionaryLiteral:
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
            properties: OrderedDictionary(
                dictionaryLiteral:
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
            properties: OrderedDictionary(
                dictionaryLiteral:
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
            properties: OrderedDictionary(
                dictionaryLiteral:
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
            properties: OrderedDictionary(
                dictionaryLiteral:
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
            properties: OrderedDictionary(
                dictionaryLiteral:
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

    // MARK: - Regression locks

    //
    // These tests exist to fail loudly if the underlying JSON-string round-trip
    // in `JSONSchema.excluding(fields:)` ever drifts (upstream `JSONSchema`
    // bumps, encoder shape changes, regex-strip semantics). They lock structural
    // properties — nested traversal, key adjacency, idempotence — that the
    // behavioral tests above don't cover.

    @Test("excluding preserves nested object property schemas")
    func preservesNestedObject() throws {
        let address = JSONSchema.object(
            properties: OrderedDictionary(
                dictionaryLiteral:
                ("street", JSONSchema.string()),
                ("zip", JSONSchema.string())
            ),
            required: ["street", "zip"]
        )
        let schema = JSONSchema.object(
            properties: OrderedDictionary(
                dictionaryLiteral:
                ("name", JSONSchema.string()),
                ("address", address)
            ),
            required: ["name", "address"],
            additionalProperties: .boolean(false)
        )

        let reduced = schema.excluding(fields: ["name"])
        let json = try schemaDict(reduced)
        let props = json["properties"] as? [String: Any]
        let nested = props?["address"] as? [String: Any]
        let nestedProps = nested?["properties"] as? [String: Any]
        let nestedRequired = nested?["required"] as? [String] ?? []

        #expect(props?["name"] == nil)
        #expect(nestedProps?["street"] != nil)
        #expect(nestedProps?["zip"] != nil)
        #expect(nestedRequired.contains("street"))
        #expect(nestedRequired.contains("zip"))
    }

    @Test("excluding preserves array item schemas")
    func preservesArrayItems() throws {
        let item = JSONSchema.object(
            properties: OrderedDictionary(
                dictionaryLiteral:
                ("name", JSONSchema.string()),
                ("qty", JSONSchema.integer())
            ),
            required: ["name", "qty"]
        )
        let schema = JSONSchema.object(
            properties: OrderedDictionary(
                dictionaryLiteral:
                ("title", JSONSchema.string()),
                ("items", JSONSchema.array(items: item))
            ),
            required: ["title", "items"],
            additionalProperties: .boolean(false)
        )

        let reduced = schema.excluding(fields: ["title"])
        let json = try schemaDict(reduced)
        let props = json["properties"] as? [String: Any]
        let items = props?["items"] as? [String: Any]
        let itemSchema = items?["items"] as? [String: Any]
        let itemProps = itemSchema?["properties"] as? [String: Any]

        #expect(props?["title"] == nil)
        #expect(itemProps?["name"] != nil)
        #expect(itemProps?["qty"] != nil)
    }

    @Test("excluding preserves additionalProperties: false")
    func preservesAdditionalProperties() throws {
        let schema = JSONSchema.object(
            properties: OrderedDictionary(
                dictionaryLiteral:
                ("a", JSONSchema.string()),
                ("b", JSONSchema.integer())
            ),
            required: ["a", "b"],
            additionalProperties: .boolean(false)
        )

        let reduced = schema.excluding(fields: ["a"])
        let json = try schemaDict(reduced)

        #expect(json["additionalProperties"] as? Bool == false)
    }

    @Test("excluding survives schemas that emit __N__ deduplication markers")
    func survivesDeduplicationMarkers() throws {
        // The upstream JSONSchema encoder emits `__N__` substrings to
        // deduplicate structurally-identical sub-schemas. `excluding` strips
        // them in its intermediate dict via regex before `JSONSerialization`
        // would otherwise reject them. Reusing `inner` in two sibling
        // positions reliably triggers the marker emission; the test locks
        // that the round-trip still produces a usable schema with the
        // expected remaining fields.
        let inner = JSONSchema.object(
            properties: OrderedDictionary(
                dictionaryLiteral:
                ("x", JSONSchema.string()),
                ("y", JSONSchema.integer())
            ),
            required: ["x", "y"]
        )
        let schema = JSONSchema.object(
            properties: OrderedDictionary(
                dictionaryLiteral:
                ("a", inner),
                ("b", JSONSchema.array(items: inner)),
                ("c", JSONSchema.string())
            ),
            required: ["a", "b", "c"],
            additionalProperties: .boolean(false)
        )

        let reduced = schema.excluding(fields: ["c"])
        let dict = try schemaDict(reduced)
        let props = dict["properties"] as? [String: Any]

        #expect(props?["a"] != nil)
        #expect(props?["b"] != nil)
        #expect(props?["c"] == nil)
    }

    @Test("excluding twice yields the same property set as excluding once")
    func idempotent() throws {
        // Idempotence at the *property-set* level. Byte-level equality is
        // not guaranteed because the round-trip goes through `[String: Any]`,
        // whose iteration order is not stable across the second pass.
        let schema = JSONSchema.object(
            properties: OrderedDictionary(
                dictionaryLiteral:
                ("a", JSONSchema.string()),
                ("b", JSONSchema.integer()),
                ("c", JSONSchema.boolean())
            ),
            required: ["a", "b", "c"],
            additionalProperties: .boolean(false)
        )

        let once = schema.excluding(fields: ["b"])
        let twice = once.excluding(fields: ["b"])

        let onceProps = try (schemaDict(once))["properties"] as? [String: Any] ?? [:]
        let twiceProps = try (schemaDict(twice))["properties"] as? [String: Any] ?? [:]
        let onceRequired = try Set(schemaDict(once)["required"] as? [String] ?? [])
        let twiceRequired = try Set(schemaDict(twice)["required"] as? [String] ?? [])

        #expect(Set(onceProps.keys) == Set(twiceProps.keys))
        #expect(onceProps.keys.sorted() == ["a", "c"])
        #expect(onceRequired == twiceRequired)
    }

    @Test("excluding non-object schema returns input unchanged")
    func nonObjectSchemaUnchanged() throws {
        let schema = JSONSchema.string(maxLength: 100)
        let reduced = schema.excluding(fields: ["anything"])

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let originalData = try encoder.encode(schema)
        let reducedData = try encoder.encode(reduced)

        #expect(originalData == reducedData)
    }

    // MARK: - Helpers

    private func schemaDict(_ schema: JSONSchema) throws -> [String: Any] {
        let data = try JSONEncoder().encode(schema)
        let sanitized = String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: "__[0-9]+__", with: "", options: .regularExpression)
        guard let jsonData = sanitized.data(using: .utf8),
              let dict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else {
            throw TestError.invalidSchema
        }
        return dict
    }

    private enum TestError: Error {
        case invalidSchema
    }
}
