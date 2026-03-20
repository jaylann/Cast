import Foundation
import JSONSchema

extension JSONSchema {

    /// Returns a new schema with the specified fields removed from properties and required.
    /// Works on object schemas. Non-object schemas are returned unchanged.
    public func excluding(fields: Set<String>) -> JSONSchema {
        guard !fields.isEmpty else { return self }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self) else { return self }
        let sanitized = String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: "__[0-9]+__", with: "", options: .regularExpression)

        guard let jsonData = sanitized.data(using: String.Encoding.utf8),
              var dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return self
        }

        if var properties = dict["properties"] as? [String: Any] {
            for field in fields {
                properties.removeValue(forKey: field)
            }
            dict["properties"] = properties
        }

        if var required = dict["required"] as? [String] {
            required.removeAll { fields.contains($0) }
            if required.isEmpty {
                dict.removeValue(forKey: "required")
            } else {
                dict["required"] = required
            }
        }

        guard let newData = try? JSONSerialization.data(withJSONObject: dict),
              let jsonString = String(data: newData, encoding: .utf8),
              let newSchema = try? JSONSchema(jsonString: jsonString) else {
            return self
        }

        return newSchema
    }
}
