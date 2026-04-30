@testable import Cast
import JSONSchema
import Testing

@Suite("PromptEngine")
struct PromptEngineTests {
    @Test func defaultSystemIncludesSchema() {
        let schema = JSONSchema.object(
            properties: ["name": .string(), "age": .integer()],
            required: ["name", "age"]
        )
        let result = PromptEngine.buildPrompt(userPrompt: "Extract info", schema: schema)

        #expect(result.system.contains("JSON Schema"))
        #expect(result.system.contains("name"))
        #expect(result.system.contains("age"))
        #expect(result.user == "Extract info")
    }

    @Test func customSystemOverride() {
        let schema = JSONSchema.object()
        let result = PromptEngine.buildPrompt(
            userPrompt: "test",
            schema: schema,
            system: "Custom system prompt."
        )
        #expect(result.system == "Custom system prompt.")
    }

    @Test func descriptionAppearsInGuidance() {
        let schema = JSONSchema.object(properties: ["title": .string()], required: ["title"])
        let annotations: [String: FieldAnnotation] = [
            "title": FieldAnnotation(description: "The movie title exactly as written")
        ]
        let result = PromptEngine.buildPrompt(userPrompt: "Extract", schema: schema, annotations: annotations)

        #expect(result.system.contains("The movie title exactly as written"))
        #expect(result.system.contains("Field guidance"))
    }

    @Test func examplesAppearInGuidance() {
        let schema = JSONSchema.object(properties: ["summary": .string()], required: ["summary"])
        let annotations: [String: FieldAnnotation] = [
            "summary": FieldAnnotation(examples: ["Great pacing", "Weak third act"])
        ]
        let result = PromptEngine.buildPrompt(userPrompt: "Summarize", schema: schema, annotations: annotations)

        #expect(result.system.contains("Great pacing"))
        #expect(result.system.contains("Weak third act"))
    }

    @Test func emptyAnnotationsNoGuidance() {
        let schema = JSONSchema.object(properties: ["x": .string()], required: ["x"])
        let result = PromptEngine.buildPrompt(userPrompt: "test", schema: schema)
        #expect(!result.system.contains("Field guidance"))
    }

    @Test func containsJSONInstruction() {
        let schema = JSONSchema.object()
        let result = PromptEngine.buildPrompt(userPrompt: "test", schema: schema)
        #expect(result.system.contains("valid JSON"))
    }

    @Test func extractionPromptWrapsTextInDelimiters() {
        let schema = JSONSchema.object()
        let source = "Invoice #4242 — total due $19.99"
        let result = PromptEngine.buildExtractionPrompt(
            text: source,
            instruction: "Extract the invoice number and total.",
            schema: schema
        )

        #expect(result.user.contains("---SOURCE---"))
        #expect(result.user.contains("---END SOURCE---"))
        #expect(result.user.contains(source))

        guard
            let startRange = result.user.range(of: "---SOURCE---"),
            let endRange = result.user.range(of: "---END SOURCE---"),
            let sourceRange = result.user.range(of: source)
        else {
            Issue.record("Expected delimiters and source text in user prompt")
            return
        }
        #expect(startRange.upperBound <= sourceRange.lowerBound)
        #expect(sourceRange.upperBound <= endRange.lowerBound)
    }

    @Test func extractionPromptIncludesInstruction() {
        let schema = JSONSchema.object()
        let instruction = "Extract the invoice number and total in USD."
        let result = PromptEngine.buildExtractionPrompt(
            text: "irrelevant",
            instruction: instruction,
            schema: schema
        )
        #expect(result.user.contains(instruction))
    }

    @Test func extractionPromptDiscouragesInvention() {
        let schema = JSONSchema.object()
        let result = PromptEngine.buildExtractionPrompt(
            text: "irrelevant",
            instruction: "Extract.",
            schema: schema
        )
        #expect(result.system.lowercased().contains("do not invent"))
        #expect(result.system.contains("null"))
    }

    @Test func extractionPromptIncludesSchema() {
        let schema = JSONSchema.object(
            properties: ["invoiceNumber": .string(), "totalUSD": .number()],
            required: ["invoiceNumber", "totalUSD"]
        )
        let result = PromptEngine.buildExtractionPrompt(
            text: "irrelevant",
            instruction: "Extract.",
            schema: schema
        )
        #expect(result.system.contains("JSON Schema"))
        #expect(result.system.contains("invoiceNumber"))
        #expect(result.system.contains("totalUSD"))
    }

    @Test func extractionPromptCustomSystemOverride() {
        let schema = JSONSchema.object()
        let result = PromptEngine.buildExtractionPrompt(
            text: "irrelevant",
            instruction: "Extract.",
            schema: schema,
            system: "Custom extraction system."
        )
        #expect(result.system == "Custom extraction system.")
    }
}
