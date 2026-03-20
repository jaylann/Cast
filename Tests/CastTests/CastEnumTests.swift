import Foundation
import Testing

@testable import Cast

enum Color: String, CastEnum {
    case red, green, blue
}

enum Priority: Int, CastEnum {
    case low = 0
    case medium = 1
    case high = 2
}

@Suite("CastEnum")
struct CastEnumTests {

    @Test("String enum generates correct JSON schema")
    func stringEnumSchema() throws {
        let schema = Color.jsonSchema
        let data = try JSONEncoder().encode(schema)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let values = json["enum"] as! [String]
        #expect(Set(values) == Set(["red", "green", "blue"]))
    }

    @Test("Int enum generates correct JSON schema")
    func intEnumSchema() throws {
        let schema = Priority.jsonSchema
        let data = try JSONEncoder().encode(schema)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let values = json["enum"] as! [Int]
        #expect(Set(values) == Set([0, 1, 2]))
    }

    @Test("String enum is Codable")
    func stringEnumCodable() throws {
        let original = Color.red
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Color.self, from: data)
        #expect(decoded == original)
    }

    @Test("Int enum is Codable")
    func intEnumCodable() throws {
        let original = Priority.high
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Priority.self, from: data)
        #expect(decoded == original)
    }

    @Test("String CastEnum conforms to CastSchemaProviding")
    func stringEnumCastSchemaProviding() {
        #expect(Color.self is any CastSchemaProviding.Type)
        let schema = Color.castSchema
        let data = try! JSONEncoder().encode(schema)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("red"))
    }
}
