import Collections
import Foundation
import JSONSchema

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
///
/// Requires a no-arg init so constraint values from default initializers are
/// preserved. The `@Castable` macro synthesizes both the init and the nested
/// ``PartiallyGenerated`` mirror — a struct of the same shape with every
/// property made `Optional` — used by ``CastModel/castStream(_:as:system:config:)``
/// to surface in-flight values as the model fills them in.
public protocol Castable: Decodable, Sendable {
    /// Mirror of `Self` whose properties are all `Optional`. Defaults to `Self`
    /// for hand-rolled `Castable` types that don't go through the macro;
    /// streamed updates of those types are emitted only at the terminal yield.
    associatedtype PartiallyGenerated: Sendable & Decodable = Self

    init()
}

// MARK: - SchemaGenerator

public enum SchemaGenerator {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var cache: [ObjectIdentifier: CacheEntry] = [:]

    private struct CacheEntry: Sendable {
        let schema: JSONSchema
        let annotations: [String: FieldAnnotation]
        let nullableFields: Set<String>
    }

    public static func schema(for type: (some Decodable & Sendable).Type) throws -> JSONSchema {
        try cached(type).schema
    }

    public static func annotations(for type: (some Decodable & Sendable).Type) throws -> [String: FieldAnnotation] {
        try cached(type).annotations
    }

    public static func nullableFields(for type: (some Decodable & Sendable).Type) throws -> Set<String> {
        try cached(type).nullableFields
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
                    if let v = prop.value as? Int { constraints.intMin = v } else if let v = prop.value as? Double { constraints.doubleMin = v }
                case "upperBound":
                    if let v = prop.value as? Int { constraints.intMax = v } else if let v = prop.value as? Double { constraints.doubleMax = v }
                case "maxCount":
                    constraints.maxItems = prop.value as? Int
                case "minCount":
                    constraints.minItems = prop.value as? Int
                case "values":
                    if let vals = prop.value as? [String] {
                        constraints.oneOfValues = vals
                    }
                case "pattern":
                    constraints.pattern = prop.value as? String
                case "precision":
                    if let p = prop.value as? Int {
                        constraints.multipleOf = pow(10.0, -Double(p))
                    }
                case "count":
                    constraints.exactCount = prop.value as? Int
                case "isNullable":
                    constraints.isNullable = (prop.value as? Bool) ?? false
                case "defaultValue", "transform":
                    break
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

        var nullableFieldNames = Set<String>()
        for (name, c) in constraintsMap where c.isNullable {
            nullableFieldNames.insert(name)
        }

        var properties = OrderedDictionary<String, JSONSchema>()
        for field in info.fields {
            let desc = annotationsMap[field.name]?.description
            if let constraints = constraintsMap[field.name] {
                properties[field.name] = applyConstraints(constraints, kind: field.kind, description: desc)
            } else if let desc {
                switch field.kind {
                case .object, .enumeration:
                    properties[field.name] = field.schema
                default:
                    properties[field.name] = withDescription(field.kind, desc)
                }
            } else {
                properties[field.name] = field.schema
            }
        }

        let required = info.required.filter { !nullableFieldNames.contains($0) }
        let schema = JSONSchema.object(
            properties: properties,
            required: required.isEmpty ? nil : required,
            additionalProperties: .boolean(false)
        )

        return CacheEntry(schema: schema, annotations: annotationsMap, nullableFields: nullableFieldNames)
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
            return .string(description: description, minLength: c.minLength, maxLength: c.maxLength, pattern: c.pattern)
        case .integer:
            return .integer(description: description, minimum: c.intMin, maximum: c.intMax)
        case .number:
            return .number(
                description: description,
                multipleOf: c.multipleOf,
                minimum: c.doubleMin,
                maximum: c.doubleMax
            )
        case let .array(element):
            let itemSchema = baseSchema(for: element)
            return .array(
                description: description,
                items: itemSchema,
                minItems: c.exactCount ?? c.minItems,
                maxItems: c.exactCount ?? c.maxItems
            )
        default:
            if let description {
                return withDescription(kind, description)
            }
            return baseSchema(for: kind)
        }
    }

    /// Create a base schema from SchemaKind with just a description.
    private static func withDescription(_ kind: SchemaKind, _ desc: String) -> JSONSchema {
        switch kind {
        case .string: .string(description: desc)
        case .integer: .integer(description: desc)
        case .number: .number(description: desc)
        case .boolean: .boolean(description: desc)
        case let .array(element):
            .array(description: desc, items: baseSchema(for: element))
        case .object, .enumeration:
            baseSchema(for: kind)
        }
    }

    /// Convert a SchemaKind to a basic JSONSchema (no constraints).
    private static func baseSchema(for kind: SchemaKind) -> JSONSchema {
        switch kind {
        case .string: .string()
        case .integer: .integer()
        case .number: .number()
        case .boolean: .boolean()
        case let .array(element): .array(items: baseSchema(for: element))
        case .object: .object()
        case .enumeration: .string()
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
    var pattern: String?
    var multipleOf: Double?
    var exactCount: Int?
    var isNullable: Bool = false

    var hasConstraints: Bool {
        maxLength != nil || minLength != nil ||
            intMin != nil || intMax != nil ||
            doubleMin != nil || doubleMax != nil ||
            maxItems != nil || minItems != nil ||
            oneOfValues != nil ||
            pattern != nil || multipleOf != nil ||
            exactCount != nil || isNullable
    }
}
