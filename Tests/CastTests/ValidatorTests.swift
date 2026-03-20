import Foundation
import Testing

@testable import Cast

private func trimmed(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespaces)
}

private func uppercased(_ value: String) -> String {
    value.uppercased()
}

private func clamped(_ value: Int) -> Int {
    max(1, min(10, value))
}

private func stripPrefix(_ value: String) -> String {
    value.replacingOccurrences(of: "^[A-Z]+ ", with: "", options: .regularExpression)
}

private struct ValidatedStruct: Castable, Encodable {
    @Validator(trimmed) var name: String = ""
    @Validator(clamped) var rating: Int = 0
    var plain: String = ""
    init() {}
}

private struct MultiValidatorStruct: Castable, Encodable {
    @Validator(uppercased) var code: String = ""
    @Validator(stripPrefix) var trainNumber: String = ""
    var city: String = ""
    init() {}
}

@Suite("Validator")
struct ValidatorTests {

    @Test("Validator transform applied during Cast decode")
    func transformApplied() throws {
        let json = #"{"name": "  hello  ", "rating": 15, "plain": "unchanged"}"#
        let data = Data(json.utf8)

        let result = try ValidatorSupport.decode(ValidatedStruct.self, from: data)

        #expect(result.name == "hello")
        #expect(result.rating == 10)
        #expect(result.plain == "unchanged")
    }

    @Test("Validator clamps value within range")
    func clampLow() throws {
        let json = #"{"name": "test", "rating": -5, "plain": ""}"#
        let data = Data(json.utf8)

        let result = try ValidatorSupport.decode(ValidatedStruct.self, from: data)

        #expect(result.rating == 1)
    }

    @Test("Validator passes through valid values unchanged")
    func passThroughValid() throws {
        let json = #"{"name": "clean", "rating": 5, "plain": "ok"}"#
        let data = Data(json.utf8)

        let result = try ValidatorSupport.decode(ValidatedStruct.self, from: data)

        #expect(result.name == "clean")
        #expect(result.rating == 5)
    }

    @Test("Multiple validators on different fields")
    func multipleValidators() throws {
        let json = #"{"code": "abc", "trainNumber": "ICE 09725", "city": "Berlin"}"#
        let data = Data(json.utf8)

        let result = try ValidatorSupport.decode(MultiValidatorStruct.self, from: data)

        #expect(result.code == "ABC")
        #expect(result.trainNumber == "09725")
        #expect(result.city == "Berlin")
    }

    @Test("Validator wrapper is Codable transparent")
    func codableTransparent() throws {
        var s = ValidatedStruct()
        s.name = "test"
        s.rating = 5
        s.plain = "ok"

        let encoded = try JSONEncoder().encode(s)
        let dict = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]

        let nameVal = dict?["name"] as? String
        #expect(nameVal == "test")
        let ratingVal = dict?["rating"] as? Int
        #expect(ratingVal == 5)
    }

    @Test("Validator constraint readable via Mirror")
    func mirrorReadable() {
        let instance = ValidatedStruct()
        let mirror = Mirror(reflecting: instance)
        let child = mirror.children.first { $0.label == "_name" }!
        let wrapper = child.value as! Validator<String>
        #expect(wrapper.transform("  spaces  ") == "spaces")
    }

    @Test("Validator does not affect schema")
    func noSchemaEffect() throws {
        let schema = try SchemaGenerator.schema(for: ValidatedStruct.self)
        let data = try JSONEncoder().encode(schema)
        let str = String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: "__[0-9]+__", with: "", options: .regularExpression)

        #expect(str.contains("\"name\""))
        #expect(str.contains("\"rating\""))
        #expect(str.contains("\"plain\""))
        #expect(!str.contains("transform"))
    }

    @Test("Non-Castable types decode normally without validators")
    func nonCastableFallback() throws {
        struct Plain: Decodable, Sendable { let x: Int }
        let json = #"{"x": 42}"#
        let result = try ValidatorSupport.decode(Plain.self, from: Data(json.utf8))
        #expect(result.x == 42)
    }
}
