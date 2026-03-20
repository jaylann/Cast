import Foundation
import JSONSchema

public enum PromptEngine {

    public static func buildPrompt(
        userPrompt: String,
        schema: JSONSchema,
        annotations: [String: FieldAnnotation] = [:],
        system: String? = nil
    ) -> (system: String, user: String) {
        let systemPrompt: String
        if let system {
            systemPrompt = system
        } else {
            systemPrompt = buildDefaultSystem(schema: schema, annotations: annotations)
        }
        return (system: systemPrompt, user: userPrompt)
    }

    private static func buildDefaultSystem(
        schema: JSONSchema,
        annotations: [String: FieldAnnotation]
    ) -> String {
        var parts: [String] = []

        parts.append("You are a structured data extraction assistant.")
        parts.append("Respond ONLY with valid JSON matching the following schema.")
        parts.append("")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        if let data = try? encoder.encode(schema),
           let str = String(data: data, encoding: .utf8) {
            parts.append("JSON Schema:")
            parts.append(str)
        } else {
            parts.append("[Schema encoding failed]")
        }

        let guidance = annotations.sorted(by: { $0.key < $1.key }).compactMap { field, ann -> String? in
            var items: [String] = []
            if let d = ann.description { items.append(d) }
            if let e = ann.examples, !e.isEmpty { items.append("Examples: \(e.joined(separator: ", "))") }
            guard !items.isEmpty else { return nil }
            return "- \(field): \(items.joined(separator: ". "))"
        }

        if !guidance.isEmpty {
            parts.append("")
            parts.append("Field guidance:")
            parts.append(contentsOf: guidance)
        }

        parts.append("")
        parts.append("Output valid JSON only. No markdown, no explanation.")

        return parts.joined(separator: "\n")
    }
}
