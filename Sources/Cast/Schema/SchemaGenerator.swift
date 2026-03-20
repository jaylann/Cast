import Foundation
import JSONSchema
import Collections

// MARK: - FieldAnnotation

public struct FieldAnnotation: Sendable {
    public let description: String?
    public let examples: [String]?

    public init(description: String? = nil, examples: [String]? = nil) {
        self.description = description
        self.examples = examples
    }
}

// MARK: - Castable

/// Types using Cast property wrappers must conform to Castable.
/// Requires a no-arg init so constraint values from default initializers are preserved.
/// The @Castable macro (Phase 2) will synthesize this automatically.
public protocol Castable: Decodable, Sendable {
    init()
}

// MARK: - SchemaGenerator

public enum SchemaGenerator {

    private static let lock = NSLock()
    private static nonisolated(unsafe) var cache: [ObjectIdentifier: CacheEntry] = [:]

    private struct CacheEntry: Sendable {
        let schema: JSONSchema
        let annotations: [String: FieldAnnotation]
    }

    public static func schema(for type: (some Decodable & Sendable).Type) throws -> JSONSchema {
        try cached(type).schema
    }

    public static func annotations(for type: (some Decodable & Sendable).Type) throws -> [String: FieldAnnotation] {
        try cached(type).annotations
    }

    // MARK: - Private

    private static func cached(_ type: (some Decodable & Sendable).Type) throws -> CacheEntry {
        let id = ObjectIdentifier(type)

        lock.lock()
        if let entry = cache[id] {
            lock.unlock()
            return entry
        }
        lock.unlock()

        let entry = try build(type)

        lock.lock()
        cache[id] = entry
        lock.unlock()

        return entry
    }

    private static func build(_ type: (some Decodable & Sendable).Type) throws -> CacheEntry {
        let info = try ZeroSchemaDecoder.decode(type)

        // Use Castable.init() when available — preserves property wrapper constraint values.
        // The ZeroSchemaDecoder instance loses constraints because wrappers' Decodable init
        // can't reconstruct them from JSON.
        let mirrorInstance: any Sendable
        if let castableType = type as? any Castable.Type {
            mirrorInstance = castableType.init() as! any Sendable
        } else {
            mirrorInstance = info.zeroInstance
        }
        let mirror = Mirror(reflecting: mirrorInstance)

        var constraintsMap: [String: FieldConstraints] = [:]
        var annotationsMap: [String: FieldAnnotation] = [:]

        for child in mirror.children {
            guard let label = child.label else { continue }
            guard label.hasPrefix("_") else { continue }
            let fieldName = String(label.dropFirst())

            let wrapperMirror = Mirror(reflecting: child.value)
            var constraints = FieldConstraints()
            var descriptionText: String?
            var examples: [String]?

            for prop in wrapperMirror.children {
                guard let propLabel = prop.label else { continue }
                switch propLabel {
                case "maxLength":
                    constraints.maxLength = prop.value as? Int
                case "minLength":
                    constraints.minLength = prop.value as? Int
                case "lowerBound":
                    if let v = prop.value as? Int { constraints.intMin = v }
                    else if let v = prop.value as? Double { constraints.doubleMin = v }
                case "upperBound":
                    if let v = prop.value as? Int { constraints.intMax = v }
                    else if let v = prop.value as? Double { constraints.doubleMax = v }
                case "maxCount":
                    constraints.maxItems = prop.value as? Int
                case "minCount":
                    constraints.minItems = prop.value as? Int
                case "values":
                    if let vals = prop.value as? [String] {
                        constraints.oneOfValues = vals
                    }
                case "descriptionText":
                    descriptionText = prop.value as? String
                case "examples":
                    examples = prop.value as? [String]
                default:
                    break
                }
            }

            if constraints.hasConstraints {
                constraintsMap[fieldName] = constraints
            }
            if descriptionText != nil || examples != nil {
                annotationsMap[fieldName] = FieldAnnotation(
                    description: descriptionText,
                    examples: examples
                )
            }
        }

        var properties = OrderedDictionary<String, JSONSchema>()
        for field in info.fields {
            let desc = annotationsMap[field.name]?.description
            if let constraints = constraintsMap[field.name] {
                properties[field.name] = applyConstraints(constraints, kind: field.kind, description: desc)
            } else if let desc {
                properties[field.name] = withDescription(field.kind, desc)
            } else {
                properties[field.name] = field.schema
            }
        }

        let schema = JSONSchema.object(
            properties: properties,
            required: info.required.isEmpty ? nil : info.required,
            additionalProperties: .boolean(false)
        )

        return CacheEntry(schema: schema, annotations: annotationsMap)
    }

    /// Build a new JSONSchema from constraints, using SchemaKind to determine the type.
    private static func applyConstraints(
        _ c: FieldConstraints,
        kind: SchemaKind,
        description: String?
    ) -> JSONSchema {
        if let values = c.oneOfValues {
            return .enum(
                description: description,
                values: values.map { .string($0) }
            )
        }

        switch kind {
        case .string:
            return .string(description: description, minLength: c.minLength, maxLength: c.maxLength)
        case .integer:
            return .integer(description: description, minimum: c.intMin, maximum: c.intMax)
        case .number:
            return .number(description: description, minimum: c.doubleMin, maximum: c.doubleMax)
        case .array(let element):
            let itemSchema = baseSchema(for: element)
            return .array(description: description, items: itemSchema, minItems: c.minItems, maxItems: c.maxItems)
        default:
            return withDescription(kind, description ?? "")
        }
    }

    /// Create a base schema from SchemaKind with just a description.
    private static func withDescription(_ kind: SchemaKind, _ desc: String) -> JSONSchema {
        switch kind {
        case .string: return .string(description: desc)
        case .integer: return .integer(description: desc)
        case .number: return .number(description: desc)
        case .boolean: return .boolean(description: desc)
        case .array(let element):
            return .array(description: desc, items: baseSchema(for: element))
        case .object, .enumeration:
            // For object/enum with description, we'd need the original schema
            // but description on nested objects is uncommon; return as-is
            return .string(description: desc)
        }
    }

    /// Convert a SchemaKind to a basic JSONSchema (no constraints).
    private static func baseSchema(for kind: SchemaKind) -> JSONSchema {
        switch kind {
        case .string: return .string()
        case .integer: return .integer()
        case .number: return .number()
        case .boolean: return .boolean()
        case .array(let element): return .array(items: baseSchema(for: element))
        case .object: return .object()
        case .enumeration: return .string()
        }
    }
}

// MARK: - FieldConstraints

private struct FieldConstraints {
    var maxLength: Int?
    var minLength: Int?
    var intMin: Int?
    var intMax: Int?
    var doubleMin: Double?
    var doubleMax: Double?
    var maxItems: Int?
    var minItems: Int?
    var oneOfValues: [String]?

    var hasConstraints: Bool {
        maxLength != nil || minLength != nil ||
        intMin != nil || intMax != nil ||
        doubleMin != nil || doubleMax != nil ||
        maxItems != nil || minItems != nil ||
        oneOfValues != nil
    }
}
