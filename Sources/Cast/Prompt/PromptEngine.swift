import Foundation
import JSONSchema

public enum PromptEngine {
    public static func buildPrompt(
        userPrompt: String,
        schema: JSONSchema,
        annotations: [String: FieldAnnotation] = [:],
        system: String? = nil
    ) -> (system: String, user: String) {
        let systemPrompt: String = if let system {
            system
        } else {
            buildDefaultSystem(schema: schema, annotations: annotations)
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

    public static func buildClassificationPrompt(
        userPrompt: String,
        enumValues: [String],
        system: String? = nil
    ) -> (system: String, user: String) {
        let systemPrompt = system ?? buildClassificationSystem(enumValues: enumValues)
        return (system: systemPrompt, user: userPrompt)
    }

    private static func buildClassificationSystem(enumValues: [String]) -> String {
        var parts: [String] = []
        parts.append("You are a classifier.")
        parts.append("Classify the input into exactly one of these categories: \(enumValues.joined(separator: ", ")).")
        parts.append("")
        parts.append("Respond with ONLY the category name as a JSON string.")
        parts.append("No explanation, no markdown.")
        return parts.joined(separator: "\n")
    }

    /// Build an extraction-optimized prompt: wraps the source `text` in
    /// unambiguous delimiters and tells the model not to invent fields.
    /// The system message embeds the JSON schema (same shape as
    /// ``buildPrompt(userPrompt:schema:annotations:system:)``); when `system`
    /// is supplied, it is returned verbatim as the system message.
    ///
    /// - Parameters:
    ///   - text: The unstructured source text to extract from.
    ///   - instruction: The extraction instruction (e.g. "Extract the
    ///     invoice number and total in USD").
    ///   - schema: The JSON schema the output must conform to.
    ///   - annotations: Optional per-field guidance (description, examples).
    ///   - system: Optional override for the system message.
    public static func buildExtractionPrompt(
        text: String,
        instruction: String,
        schema: JSONSchema,
        annotations: [String: FieldAnnotation] = [:],
        system: String? = nil
    ) -> (system: String, user: String) {
        let systemPrompt = system ?? buildExtractionSystem(schema: schema, annotations: annotations)
        let user = buildExtractionUser(text: text, instruction: instruction)
        return (system: systemPrompt, user: user)
    }

    private static func buildExtractionSystem(
        schema: JSONSchema,
        annotations: [String: FieldAnnotation]
    ) -> String {
        var parts: [String] = []

        parts.append("You are a structured data extraction assistant.")
        parts
            .append(
                "Extract the requested fields from the source. If a field is not present, use null. Do not invent information."
            )
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

    private static func buildExtractionUser(text: String, instruction: String) -> String {
        // Delimiters separate untrusted source text from the extraction
        // instruction, mitigating prompt-injection from the source body.
        var parts: [String] = []
        parts.append(instruction)
        parts.append("")
        parts.append("---SOURCE---")
        parts.append(text)
        parts.append("---END SOURCE---")
        return parts.joined(separator: "\n")
    }
}
