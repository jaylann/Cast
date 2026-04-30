import Foundation
import JSONSchema

/// A `RawRepresentable` enum whose cases form a closed set of valid outputs for
/// ``CastModel/classify(_:as:system:config:didGenerate:)-3sl4w``.
///
/// Adopt with `String` or `Int` raw values; Cast emits a JSON Schema `enum`
/// from `allCases` and constrains decoding to those values.
///
/// ```swift
/// enum Sentiment: String, CastEnum { case positive, neutral, negative }
/// ```
public protocol CastEnum: RawRepresentable, CaseIterable, Codable, Sendable,
    CastSchemaProviding, _FirstCaseProvider
    where RawValue: Sendable {}

public extension CastEnum where RawValue == String {
    static var jsonSchema: JSONSchema {
        .enum(values: allCases.map { .string($0.rawValue) })
    }

    static var castSchema: JSONSchema {
        jsonSchema
    }

    static var _firstCaseAny: Any {
        allCases.first(where: { _ in true })!
    }
}

public extension CastEnum where RawValue == Int {
    static var jsonSchema: JSONSchema {
        .enum(values: allCases.map { .integer($0.rawValue) })
    }

    static var castSchema: JSONSchema {
        jsonSchema
    }

    static var _firstCaseAny: Any {
        allCases.first(where: { _ in true })!
    }
}
