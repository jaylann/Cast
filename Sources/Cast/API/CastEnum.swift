import Foundation
import JSONSchema

public protocol CastEnum: RawRepresentable, CaseIterable, Codable, Sendable, CastSchemaProviding
    where RawValue: Sendable {}

extension CastEnum where RawValue == String {
    public static var jsonSchema: JSONSchema {
        .enum(values: allCases.map { .string($0.rawValue) })
    }

    public static var castSchema: JSONSchema { jsonSchema }
}

extension CastEnum where RawValue == Int {
    public static var jsonSchema: JSONSchema {
        .enum(values: allCases.map { .integer($0.rawValue) })
    }

    public static var castSchema: JSONSchema { jsonSchema }
}
