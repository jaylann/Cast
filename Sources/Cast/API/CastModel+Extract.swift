import Foundation
import JSONSchema
@preconcurrency import MLXLMCommon

public extension CastModel {
    /// Extract structured fields from a block of unstructured text. Builds an
    /// extraction-optimized prompt that wraps `text` in delimiters and tells
    /// the model not to invent fields, then delegates to ``cast(_:as:schema:system:config:didGenerate:)``.
    ///
    /// ```swift
    /// @Castable struct InvoiceFields { var invoiceNumber: String = ""; var totalUSD: Double = 0 }
    /// let fields: InvoiceFields = try await model.extract(
    ///     from: invoiceText,
    ///     instruction: "Extract the invoice number and total in USD."
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - text: The unstructured source text to extract from.
    ///   - type: Target type. Usually inferred.
    ///   - instruction: What to extract (e.g. "Extract the invoice number and
    ///     total in USD.").
    ///   - system: Optional override for the auto-built system message.
    ///   - config: Sampling, timeout, and JSON-repair knobs.
    ///   - didGenerate: Optional per-token hook returning `.stop` to end early.
    /// - Throws: Same errors as ``cast(_:as:system:config:didGenerate:)``.
    func extract<T: Decodable & Sendable>(
        from text: String,
        as type: T.Type = T.self,
        instruction: String,
        system: String? = nil,
        config: CastConfiguration = CastConfiguration(),
        didGenerate: (@Sendable (Int) -> GenerateDisposition)? = nil
    ) async throws -> T {
        let schema: JSONSchema
        do {
            schema = try SchemaGenerator.schema(for: type)
        } catch {
            throw CastError.schemaGenerationFailed(error.localizedDescription)
        }

        let annotations = (try? SchemaGenerator.annotations(for: type)) ?? [:]
        let built = PromptEngine.buildExtractionPrompt(
            text: text,
            instruction: instruction,
            schema: schema,
            annotations: annotations,
            system: system
        )

        return try await cast(
            built.user,
            as: type,
            schema: schema,
            system: built.system,
            config: config,
            didGenerate: didGenerate
        )
    }
}
