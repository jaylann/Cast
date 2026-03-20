import Foundation

// All wrappers are Codable-transparent: they encode/decode the wrappedValue only.
// Constraint metadata is used at schema-generation time (via Mirror), not at JSON encode/decode time.

@propertyWrapper
public struct MaxLength<Value: Sendable>: Sendable {
    public var wrappedValue: Value
    public let maxLength: Int

    public init(wrappedValue: Value, _ maxLength: Int) {
        self.wrappedValue = wrappedValue
        self.maxLength = maxLength
    }
}

extension MaxLength: Encodable where Value: Encodable {
    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension MaxLength: Decodable where Value: Decodable {
    public init(from decoder: Decoder) throws {
        self.wrappedValue = try Value(from: decoder)
        self.maxLength = 0
    }
}

@propertyWrapper
public struct MinLength<Value: Sendable>: Sendable {
    public var wrappedValue: Value
    public let minLength: Int

    public init(wrappedValue: Value, _ minLength: Int) {
        self.wrappedValue = wrappedValue
        self.minLength = minLength
    }
}

extension MinLength: Encodable where Value: Encodable {
    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension MinLength: Decodable where Value: Decodable {
    public init(from decoder: Decoder) throws {
        self.wrappedValue = try Value(from: decoder)
        self.minLength = 0
    }
}

@propertyWrapper
public struct CastRange<Value: Sendable, Bound: Comparable & Sendable>: Sendable {
    public var wrappedValue: Value
    public let lowerBound: Bound
    public let upperBound: Bound

    public init(wrappedValue: Value, _ range: ClosedRange<Bound>) {
        self.wrappedValue = wrappedValue
        self.lowerBound = range.lowerBound
        self.upperBound = range.upperBound
    }
}

extension CastRange: Encodable where Value: Encodable {
    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension CastRange: Decodable where Value: Decodable, Bound: Decodable {
    public init(from decoder: Decoder) throws {
        self.wrappedValue = try Value(from: decoder)
        self.lowerBound = try Bound(from: _ZeroDecoder())
        self.upperBound = try Bound(from: _ZeroDecoder())
    }
}

@propertyWrapper
public struct MaxCount<Value: Sendable>: Sendable {
    public var wrappedValue: Value
    public let maxCount: Int

    public init(wrappedValue: Value, _ maxCount: Int) {
        self.wrappedValue = wrappedValue
        self.maxCount = maxCount
    }
}

extension MaxCount: Encodable where Value: Encodable {
    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension MaxCount: Decodable where Value: Decodable {
    public init(from decoder: Decoder) throws {
        self.wrappedValue = try Value(from: decoder)
        self.maxCount = 0
    }
}

@propertyWrapper
public struct MinCount<Value: Sendable>: Sendable {
    public var wrappedValue: Value
    public let minCount: Int

    public init(wrappedValue: Value, _ minCount: Int) {
        self.wrappedValue = wrappedValue
        self.minCount = minCount
    }
}

extension MinCount: Encodable where Value: Encodable {
    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension MinCount: Decodable where Value: Decodable {
    public init(from decoder: Decoder) throws {
        self.wrappedValue = try Value(from: decoder)
        self.minCount = 0
    }
}

@propertyWrapper
public struct OneOf<Value: Sendable>: Sendable {
    public var wrappedValue: Value
    public let values: [String]

    public init(wrappedValue: Value, _ values: [String]) {
        self.wrappedValue = wrappedValue
        self.values = values
    }
}

extension OneOf: Encodable where Value: Encodable {
    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension OneOf: Decodable where Value: Decodable {
    public init(from decoder: Decoder) throws {
        self.wrappedValue = try Value(from: decoder)
        self.values = []
    }
}

@propertyWrapper
public struct Description<Value: Sendable>: Sendable {
    public var wrappedValue: Value
    public let descriptionText: String

    public init(wrappedValue: Value, _ descriptionText: String) {
        self.wrappedValue = wrappedValue
        self.descriptionText = descriptionText
    }
}

extension Description: Encodable where Value: Encodable {
    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension Description: Decodable where Value: Decodable {
    public init(from decoder: Decoder) throws {
        self.wrappedValue = try Value(from: decoder)
        self.descriptionText = ""
    }
}

@propertyWrapper
public struct Examples<Value: Sendable>: Sendable {
    public var wrappedValue: Value
    public let examples: [String]

    public init(wrappedValue: Value, _ examples: String...) {
        self.wrappedValue = wrappedValue
        self.examples = examples
    }
}

extension Examples: Encodable where Value: Encodable {
    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension Examples: Decodable where Value: Decodable {
    public init(from decoder: Decoder) throws {
        self.wrappedValue = try Value(from: decoder)
        self.examples = []
    }
}

@propertyWrapper
public struct Pattern<Value: Sendable>: Sendable {
    public var wrappedValue: Value
    public let pattern: String

    public init(wrappedValue: Value, _ pattern: String) {
        self.wrappedValue = wrappedValue
        self.pattern = pattern
    }
}

extension Pattern: Encodable where Value: Encodable {
    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension Pattern: Decodable where Value: Decodable {
    public init(from decoder: Decoder) throws {
        self.wrappedValue = try Value(from: decoder)
        self.pattern = ""
    }
}

@propertyWrapper
public struct Precision<Value: Sendable>: Sendable {
    public var wrappedValue: Value
    public let precision: Int

    public init(wrappedValue: Value, _ precision: Int) {
        self.wrappedValue = wrappedValue
        self.precision = precision
    }
}

extension Precision: Encodable where Value: Encodable {
    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension Precision: Decodable where Value: Decodable {
    public init(from decoder: Decoder) throws {
        self.wrappedValue = try Value(from: decoder)
        self.precision = 0
    }
}

@propertyWrapper
public struct Count<Value: Sendable>: Sendable {
    public var wrappedValue: Value
    public let count: Int

    public init(wrappedValue: Value, _ count: Int) {
        self.wrappedValue = wrappedValue
        self.count = count
    }
}

extension Count: Encodable where Value: Encodable {
    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension Count: Decodable where Value: Decodable {
    public init(from decoder: Decoder) throws {
        self.wrappedValue = try Value(from: decoder)
        self.count = 0
    }
}

@propertyWrapper
public struct Nullable<Value: Sendable>: Sendable {
    public var wrappedValue: Value
    public let isNullable: Bool

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
        self.isNullable = true
    }
}

extension Nullable: Encodable where Value: Encodable {
    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension Nullable: Decodable where Value: Decodable {
    public init(from decoder: Decoder) throws {
        self.wrappedValue = try Value(from: decoder)
        self.isNullable = false
    }
}

@propertyWrapper
public struct DefaultValue<Value: Sendable>: Sendable {
    public var wrappedValue: Value
    public let defaultValue: Value

    public init(wrappedValue: Value, _ defaultValue: Value) {
        self.wrappedValue = wrappedValue
        self.defaultValue = defaultValue
    }
}

extension DefaultValue: Encodable where Value: Encodable {
    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension DefaultValue: Decodable where Value: Decodable {
    public init(from decoder: Decoder) throws {
        self.wrappedValue = try Value(from: decoder)
        self.defaultValue = try Value(from: _ZeroDecoder())
    }
}

@propertyWrapper
public struct Validator<Value: Sendable>: Sendable {
    public var wrappedValue: Value
    public let transform: @Sendable (Value) -> Value

    public init(wrappedValue: Value, _ transform: @escaping @Sendable (Value) -> Value) {
        self.wrappedValue = wrappedValue
        self.transform = transform
    }
}

extension Validator: Encodable where Value: Encodable {
    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension Validator: Decodable where Value: Decodable {
    public init(from decoder: Decoder) throws {
        self.wrappedValue = try Value(from: decoder)
        self.transform = { $0 }
    }
}

/// Internal protocol for type-erased validator transform application.
protocol _ValidatorApplicable {
    func _applyTransform(_ value: Any) -> Any
}

extension Validator: _ValidatorApplicable {
    func _applyTransform(_ value: Any) -> Any {
        guard let typed = value as? Value else { return value }
        return transform(typed) as Any
    }
}

// Minimal decoder that produces zero values for Bound types in CastRange
struct _ZeroDecoder: Decoder {
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]
    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: ""))
    }
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: ""))
    }
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        _ZeroSingleValueContainer()
    }
}

private struct _ZeroSingleValueContainer: SingleValueDecodingContainer {
    var codingPath: [CodingKey] = []
    func decodeNil() -> Bool { false }
    func decode(_ type: Bool.Type) throws -> Bool { false }
    func decode(_ type: String.Type) throws -> String { "" }
    func decode(_ type: Double.Type) throws -> Double { 0 }
    func decode(_ type: Float.Type) throws -> Float { 0 }
    func decode(_ type: Int.Type) throws -> Int { 0 }
    func decode(_ type: Int8.Type) throws -> Int8 { 0 }
    func decode(_ type: Int16.Type) throws -> Int16 { 0 }
    func decode(_ type: Int32.Type) throws -> Int32 { 0 }
    func decode(_ type: Int64.Type) throws -> Int64 { 0 }
    func decode(_ type: UInt.Type) throws -> UInt { 0 }
    func decode(_ type: UInt8.Type) throws -> UInt8 { 0 }
    func decode(_ type: UInt16.Type) throws -> UInt16 { 0 }
    func decode(_ type: UInt32.Type) throws -> UInt32 { 0 }
    func decode(_ type: UInt64.Type) throws -> UInt64 { 0 }
    func decode<T: Decodable>(_ type: T.Type) throws -> T { try T(from: _ZeroDecoder()) }
}
