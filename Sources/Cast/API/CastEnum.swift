import Foundation
import JSONSchema

public protocol CastEnum: RawRepresentable, CaseIterable, Codable, Sendable,
    CastSchemaProviding, _FirstCaseProvider
    where RawValue: Sendable {}

extension CastEnum where RawValue == String {
    public static var jsonSchema: JSONSchema {
        .enum(values: allCases.map { .string($0.rawValue) })
    }

    public static var castSchema: JSONSchema { jsonSchema }

    public static var _firstCaseAny: Any { allCases.first(where: { _ in true })! }
}

extension CastEnum where RawValue == Int {
    public static var jsonSchema: JSONSchema {
        .enum(values: allCases.map { .integer($0.rawValue) })
    }

    public static var castSchema: JSONSchema { jsonSchema }

    public static var _firstCaseAny: Any { allCases.first(where: { _ in true })! }
}
