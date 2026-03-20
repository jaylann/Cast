import Foundation

/// Extracts validator transforms from a Castable template instance and applies them
/// to raw JSON values before final decode.
enum ValidatorSupport {

    /// Decode JSON data, applying any @Validator transforms found on the Castable type.
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        guard let castableType = type as? any Castable.Type else {
            return try JSONDecoder().decode(T.self, from: data)
        }

        let template = castableType.init()
        let validators = extractValidators(from: template)

        guard !validators.isEmpty else {
            return try JSONDecoder().decode(T.self, from: data)
        }

        guard var dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return try JSONDecoder().decode(T.self, from: data)
        }

        for (field, validator) in validators {
            if let value = dict[field] {
                dict[field] = validator._applyTransform(value)
            }
        }

        let modified = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(T.self, from: modified)
    }

    /// Mirror a Castable instance to find @Validator wrappers and their transforms.
    private static func extractValidators(from instance: any Sendable) -> [String: _ValidatorApplicable] {
        let mirror = Mirror(reflecting: instance)
        var result: [String: _ValidatorApplicable] = [:]

        for child in mirror.children {
            guard let label = child.label, label.hasPrefix("_") else { continue }
            let fieldName = String(label.dropFirst())

            if let validator = child.value as? _ValidatorApplicable {
                result[fieldName] = validator
            }
        }

        return result
    }
}
