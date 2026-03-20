import Foundation
import JSONSchema
import Collections

// MARK: - SchemaKind

/// Tracks the kind of schema for a field, avoiding need to inspect JSONSchema internals.
public indirect enum SchemaKind: Sendable, Equatable {
    case string
    case integer
    case number
    case boolean
    case array(element: SchemaKind)
    case object
    case enumeration
}

// MARK: - SchemaField

public struct SchemaField: Sendable {
    public let name: String
    public let schema: JSONSchema
    public let kind: SchemaKind
}

// MARK: - SchemaInfo

public struct SchemaInfo: Sendable {
    public let fields: [SchemaField]
    public let required: [String]
    public let zeroInstance: any Sendable
}

// MARK: - ZeroSchemaDecoder

/// A custom Decoder that produces zero-value instances and records field names + Swift types as JSONSchema.
public enum ZeroSchemaDecoder {

    public static func decode<T: Decodable & Sendable>(_ type: T.Type) throws -> SchemaInfo {
        let decoder = _Decoder()
        let instance = try T(from: decoder)
        return SchemaInfo(
            fields: decoder.fields,
            required: decoder.requiredFields,
            zeroInstance: instance
        )
    }
}

// MARK: - Internal Decoder

private final class _Decoder: Decoder {
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]
    var fields: [SchemaField] = []
    var requiredFields: [String] = []

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        KeyedDecodingContainer(_KeyedContainer<Key>(decoder: self))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        _UnkeyedContainer(decoder: self)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        _SingleValueContainer(decoder: self)
    }
}

// MARK: - KeyedDecodingContainer

private struct _KeyedContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
    typealias Key = K
    let decoder: _Decoder
    var codingPath: [CodingKey] { decoder.codingPath }
    var allKeys: [K] { [] }

    func contains(_ key: K) -> Bool { true }

    func decode(_ type: Bool.Type, forKey key: K) throws -> Bool {
        decoder.fields.append(SchemaField(name: key.stringValue, schema: .boolean(), kind: .boolean))
        decoder.requiredFields.append(key.stringValue)
        return false
    }

    func decode(_ type: String.Type, forKey key: K) throws -> String {
        decoder.fields.append(SchemaField(name: key.stringValue, schema: .string(), kind: .string))
        decoder.requiredFields.append(key.stringValue)
        return ""
    }

    func decode(_ type: Double.Type, forKey key: K) throws -> Double {
        decoder.fields.append(SchemaField(name: key.stringValue, schema: .number(), kind: .number))
        decoder.requiredFields.append(key.stringValue)
        return 0
    }

    func decode(_ type: Float.Type, forKey key: K) throws -> Float {
        decoder.fields.append(SchemaField(name: key.stringValue, schema: .number(), kind: .number))
        decoder.requiredFields.append(key.stringValue)
        return 0
    }

    func decode(_ type: Int.Type, forKey key: K) throws -> Int {
        decoder.fields.append(SchemaField(name: key.stringValue, schema: .integer(), kind: .integer))
        decoder.requiredFields.append(key.stringValue)
        return 0
    }

    func decode(_ type: Int8.Type, forKey key: K) throws -> Int8 {
        decoder.fields.append(SchemaField(name: key.stringValue, schema: .integer(), kind: .integer))
        decoder.requiredFields.append(key.stringValue)
        return 0
    }

    func decode(_ type: Int16.Type, forKey key: K) throws -> Int16 {
        decoder.fields.append(SchemaField(name: key.stringValue, schema: .integer(), kind: .integer))
        decoder.requiredFields.append(key.stringValue)
        return 0
    }

    func decode(_ type: Int32.Type, forKey key: K) throws -> Int32 {
        decoder.fields.append(SchemaField(name: key.stringValue, schema: .integer(), kind: .integer))
        decoder.requiredFields.append(key.stringValue)
        return 0
    }

    func decode(_ type: Int64.Type, forKey key: K) throws -> Int64 {
        decoder.fields.append(SchemaField(name: key.stringValue, schema: .integer(), kind: .integer))
        decoder.requiredFields.append(key.stringValue)
        return 0
    }

    func decode(_ type: UInt.Type, forKey key: K) throws -> UInt {
        decoder.fields.append(SchemaField(name: key.stringValue, schema: .integer(), kind: .integer))
        decoder.requiredFields.append(key.stringValue)
        return 0
    }

    func decode(_ type: UInt8.Type, forKey key: K) throws -> UInt8 {
        decoder.fields.append(SchemaField(name: key.stringValue, schema: .integer(), kind: .integer))
        decoder.requiredFields.append(key.stringValue)
        return 0
    }

    func decode(_ type: UInt16.Type, forKey key: K) throws -> UInt16 {
        decoder.fields.append(SchemaField(name: key.stringValue, schema: .integer(), kind: .integer))
        decoder.requiredFields.append(key.stringValue)
        return 0
    }

    func decode(_ type: UInt32.Type, forKey key: K) throws -> UInt32 {
        decoder.fields.append(SchemaField(name: key.stringValue, schema: .integer(), kind: .integer))
        decoder.requiredFields.append(key.stringValue)
        return 0
    }

    func decode(_ type: UInt64.Type, forKey key: K) throws -> UInt64 {
        decoder.fields.append(SchemaField(name: key.stringValue, schema: .integer(), kind: .integer))
        decoder.requiredFields.append(key.stringValue)
        return 0
    }

    func decode<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T {
        if let (schema, kind) = schemaForArray(type) {
            decoder.fields.append(SchemaField(name: key.stringValue, schema: schema, kind: kind))
            decoder.requiredFields.append(key.stringValue)
            return try forceDecode(type)
        }

        if let schema = schemaForEnum(type) {
            decoder.fields.append(SchemaField(name: key.stringValue, schema: schema, kind: .enumeration))
            decoder.requiredFields.append(key.stringValue)
            // Use CaseIterable.first to get a valid instance (zero decode fails for enums)
            if let first = firstCase(of: type) {
                return first
            }
            return try forceDecode(type)
        }

        let nested = _Decoder()
        let value = try T(from: nested)

        // Detect property wrappers: check for wrappedValue in Mirror
        if let (schema, kind) = schemaForWrapper(value) {
            decoder.fields.append(SchemaField(name: key.stringValue, schema: schema, kind: kind))
            decoder.requiredFields.append(key.stringValue)
            return value
        }

        if !nested.fields.isEmpty {
            var props = OrderedDictionary<String, JSONSchema>()
            for field in nested.fields {
                props[field.name] = field.schema
            }
            let objectSchema = JSONSchema.object(
                properties: props,
                required: nested.requiredFields.isEmpty ? nil : nested.requiredFields,
                additionalProperties: .boolean(false)
            )
            decoder.fields.append(SchemaField(name: key.stringValue, schema: objectSchema, kind: .object))
            decoder.requiredFields.append(key.stringValue)
            return value
        }

        decoder.fields.append(SchemaField(name: key.stringValue, schema: .string(), kind: .string))
        decoder.requiredFields.append(key.stringValue)
        return value
    }

    func decodeNil(forKey key: K) throws -> Bool { false }

    // decodeIfPresent — marks field as optional (not required)
    func decodeIfPresent(_ type: Bool.Type, forKey key: K) throws -> Bool? {
        decoder.fields.append(SchemaField(name: key.stringValue, schema: .boolean(), kind: .boolean))
        return nil
    }

    func decodeIfPresent(_ type: String.Type, forKey key: K) throws -> String? {
        decoder.fields.append(SchemaField(name: key.stringValue, schema: .string(), kind: .string))
        return nil
    }

    func decodeIfPresent(_ type: Double.Type, forKey key: K) throws -> Double? {
        decoder.fields.append(SchemaField(name: key.stringValue, schema: .number(), kind: .number))
        return nil
    }

    func decodeIfPresent(_ type: Float.Type, forKey key: K) throws -> Float? {
        decoder.fields.append(SchemaField(name: key.stringValue, schema: .number(), kind: .number))
        return nil
    }

    func decodeIfPresent(_ type: Int.Type, forKey key: K) throws -> Int? {
        decoder.fields.append(SchemaField(name: key.stringValue, schema: .integer(), kind: .integer))
        return nil
    }

    func decodeIfPresent(_ type: Int8.Type, forKey key: K) throws -> Int8? {
        decoder.fields.append(SchemaField(name: key.stringValue, schema: .integer(), kind: .integer))
        return nil
    }

    func decodeIfPresent(_ type: Int16.Type, forKey key: K) throws -> Int16? {
        decoder.fields.append(SchemaField(name: key.stringValue, schema: .integer(), kind: .integer))
        return nil
    }

    func decodeIfPresent(_ type: Int32.Type, forKey key: K) throws -> Int32? {
        decoder.fields.append(SchemaField(name: key.stringValue, schema: .integer(), kind: .integer))
        return nil
    }

    func decodeIfPresent(_ type: Int64.Type, forKey key: K) throws -> Int64? {
        decoder.fields.append(SchemaField(name: key.stringValue, schema: .integer(), kind: .integer))
        return nil
    }

    func decodeIfPresent(_ type: UInt.Type, forKey key: K) throws -> UInt? {
        decoder.fields.append(SchemaField(name: key.stringValue, schema: .integer(), kind: .integer))
        return nil
    }

    func decodeIfPresent(_ type: UInt8.Type, forKey key: K) throws -> UInt8? {
        decoder.fields.append(SchemaField(name: key.stringValue, schema: .integer(), kind: .integer))
        return nil
    }

    func decodeIfPresent(_ type: UInt16.Type, forKey key: K) throws -> UInt16? {
        decoder.fields.append(SchemaField(name: key.stringValue, schema: .integer(), kind: .integer))
        return nil
    }

    func decodeIfPresent(_ type: UInt32.Type, forKey key: K) throws -> UInt32? {
        decoder.fields.append(SchemaField(name: key.stringValue, schema: .integer(), kind: .integer))
        return nil
    }

    func decodeIfPresent(_ type: UInt64.Type, forKey key: K) throws -> UInt64? {
        decoder.fields.append(SchemaField(name: key.stringValue, schema: .integer(), kind: .integer))
        return nil
    }

    func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T? {
        if let (schema, kind) = schemaForArray(type) {
            decoder.fields.append(SchemaField(name: key.stringValue, schema: schema, kind: kind))
            return nil
        }
        if let schema = schemaForEnum(type) {
            decoder.fields.append(SchemaField(name: key.stringValue, schema: schema, kind: .enumeration))
            return nil
        }
        let nested = _Decoder()
        if let value = try? T(from: nested) {
            if let (schema, kind) = schemaForWrapper(value) {
                decoder.fields.append(SchemaField(name: key.stringValue, schema: schema, kind: kind))
                return nil
            }
        }
        if !nested.fields.isEmpty {
            var props = OrderedDictionary<String, JSONSchema>()
            for field in nested.fields {
                props[field.name] = field.schema
            }
            let objectSchema = JSONSchema.object(
                properties: props,
                required: nested.requiredFields.isEmpty ? nil : nested.requiredFields,
                additionalProperties: .boolean(false)
            )
            decoder.fields.append(SchemaField(name: key.stringValue, schema: objectSchema, kind: .object))
            return nil
        }
        decoder.fields.append(SchemaField(name: key.stringValue, schema: .string(), kind: .string))
        return nil
    }

    func nestedContainer<NestedKey: CodingKey>(
        keyedBy type: NestedKey.Type, forKey key: K
    ) throws -> KeyedDecodingContainer<NestedKey> {
        let nested = _Decoder()
        nested.codingPath = codingPath + [key]
        return KeyedDecodingContainer(_KeyedContainer<NestedKey>(decoder: nested))
    }

    func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
        _UnkeyedContainer(decoder: decoder)
    }

    func superDecoder() throws -> Decoder { decoder }
    func superDecoder(forKey key: K) throws -> Decoder { decoder }
}

// MARK: - UnkeyedDecodingContainer

private struct _UnkeyedContainer: UnkeyedDecodingContainer {
    let decoder: _Decoder
    var codingPath: [CodingKey] { decoder.codingPath }
    var count: Int? { 0 }
    var isAtEnd: Bool { true }
    var currentIndex: Int { 0 }

    mutating func decode(_ type: Bool.Type) throws -> Bool { false }
    mutating func decode(_ type: String.Type) throws -> String { "" }
    mutating func decode(_ type: Double.Type) throws -> Double { 0 }
    mutating func decode(_ type: Float.Type) throws -> Float { 0 }
    mutating func decode(_ type: Int.Type) throws -> Int { 0 }
    mutating func decode(_ type: Int8.Type) throws -> Int8 { 0 }
    mutating func decode(_ type: Int16.Type) throws -> Int16 { 0 }
    mutating func decode(_ type: Int32.Type) throws -> Int32 { 0 }
    mutating func decode(_ type: Int64.Type) throws -> Int64 { 0 }
    mutating func decode(_ type: UInt.Type) throws -> UInt { 0 }
    mutating func decode(_ type: UInt8.Type) throws -> UInt8 { 0 }
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 { 0 }
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 { 0 }
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 { 0 }
    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T { try T(from: decoder) }
    mutating func decodeNil() throws -> Bool { true }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy type: NestedKey.Type
    ) throws -> KeyedDecodingContainer<NestedKey> {
        try decoder.container(keyedBy: type)
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        _UnkeyedContainer(decoder: decoder)
    }

    mutating func superDecoder() throws -> Decoder { decoder }
}

// MARK: - SingleValueDecodingContainer

private struct _SingleValueContainer: SingleValueDecodingContainer {
    let decoder: _Decoder
    var codingPath: [CodingKey] { decoder.codingPath }

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
    func decode<T: Decodable>(_ type: T.Type) throws -> T { try T(from: decoder) }
}

// MARK: - Helpers

/// Returns (JSONSchema, SchemaKind) for array types.
private func schemaForArray<T>(_ type: T.Type) -> (JSONSchema, SchemaKind)? {
    if type == [String].self { return (.array(items: .string()), .array(element: .string)) }
    if type == [Int].self { return (.array(items: .integer()), .array(element: .integer)) }
    if type == [Double].self { return (.array(items: .number()), .array(element: .number)) }
    if type == [Float].self { return (.array(items: .number()), .array(element: .number)) }
    if type == [Bool].self { return (.array(items: .boolean()), .array(element: .boolean)) }

    if let arrayType = type as? any _ArrayProtocol.Type {
        return arrayType._arraySchemaWithKind
    }

    return nil
}

/// Detects enums conforming to CastSchemaProviding.
private func schemaForEnum<T>(_ type: T.Type) -> JSONSchema? {
    if let provider = type as? any CastSchemaProviding.Type {
        return provider.castSchema
    }
    return nil
}

/// Force-decode a type using our zero decoder.
private func forceDecode<T: Decodable>(_ type: T.Type) throws -> T {
    try T(from: _Decoder())
}

/// Get the first case of a CaseIterable type, cast to T.
private func firstCase<T>(of type: T.Type) -> T? {
    guard let provider = type as? any _FirstCaseProvider.Type else { return nil }
    return provider._firstCaseAny as? T
}

/// Protocol for getting first case of CaseIterable types at runtime.
public protocol _FirstCaseProvider {
    static var _firstCaseAny: Any { get }
}

/// Detect property wrappers by checking for `wrappedValue` in Mirror.
/// Returns the schema for the wrapped value's type.
private func schemaForWrapper(_ value: Any) -> (JSONSchema, SchemaKind)? {
    let mirror = Mirror(reflecting: value)
    guard let wrappedChild = mirror.children.first(where: { $0.label == "wrappedValue" }) else {
        return nil
    }
    return schemaForValue(wrappedChild.value)
}

/// Map a runtime value to its JSONSchema based on its dynamic type.
private func schemaForValue(_ value: Any) -> (JSONSchema, SchemaKind) {
    switch value {
    case is String: return (.string(), .string)
    case is Int, is Int8, is Int16, is Int32, is Int64,
         is UInt, is UInt8, is UInt16, is UInt32, is UInt64:
        return (.integer(), .integer)
    case is Double, is Float: return (.number(), .number)
    case is Bool: return (.boolean(), .boolean)
    default:
        // Check for arrays
        let typeName = String(describing: type(of: value))
        if typeName.hasPrefix("Array<") {
            if value is [String] { return (.array(items: .string()), .array(element: .string)) }
            if value is [Int] { return (.array(items: .integer()), .array(element: .integer)) }
            if value is [Double] { return (.array(items: .number()), .array(element: .number)) }
            if value is [Bool] { return (.array(items: .boolean()), .array(element: .boolean)) }
            return (.array(items: .string()), .array(element: .string))
        }
        return (.string(), .string)
    }
}

// MARK: - Array detection protocol

protocol _ArrayProtocol {
    static var _arraySchemaWithKind: (JSONSchema, SchemaKind) { get }
}

extension Array: _ArrayProtocol where Element: Decodable {
    static var _arraySchemaWithKind: (JSONSchema, SchemaKind) {
        if Element.self == String.self { return (.array(items: .string()), .array(element: .string)) }
        if Element.self == Int.self { return (.array(items: .integer()), .array(element: .integer)) }
        if Element.self == Double.self { return (.array(items: .number()), .array(element: .number)) }
        if Element.self == Float.self { return (.array(items: .number()), .array(element: .number)) }
        if Element.self == Bool.self { return (.array(items: .boolean()), .array(element: .boolean)) }

        let nested = _Decoder()
        _ = try? Element(from: nested)
        if !nested.fields.isEmpty {
            var props = OrderedDictionary<String, JSONSchema>()
            for field in nested.fields {
                props[field.name] = field.schema
            }
            return (.array(items: .object(
                properties: props,
                required: nested.requiredFields.isEmpty ? nil : nested.requiredFields,
                additionalProperties: .boolean(false)
            )), .array(element: .object))
        }
        return (.array(items: .string()), .array(element: .string))
    }
}

// MARK: - CastSchemaProviding

/// Conform enum types to this protocol to provide custom JSONSchema.
public protocol CastSchemaProviding {
    static var castSchema: JSONSchema { get }
}
