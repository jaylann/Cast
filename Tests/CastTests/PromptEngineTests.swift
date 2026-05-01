@testable import Cast
import JSONSchema
import Testing

@Suite("PromptEngine")
struct PromptEngineTests {
    @Test func defaultSystemIncludesSchema() throws {
        let schema = JSONSchema.object(
            properties: ["name": .string(), "age": .integer()],
            required: ["name", "age"]
        )
        let result = try PromptEngine.buildPrompt(userPrompt: "Extract info", schema: schema)

        #expect(result.system.contains("JSON Schema"))
        #expect(result.system.contains("name"))
        #expect(result.system.contains("age"))
        #expect(result.user == "Extract info")
    }

    @Test func customSystemOverride() throws {
        let schema = JSONSchema.object()
        let result = try PromptEngine.buildPrompt(
            userPrompt: "test",
            schema: schema,
            system: "Custom system prompt."
        )
        #expect(result.system == "Custom system prompt.")
    }

    @Test func descriptionAppearsInGuidance() throws {
        let schema = JSONSchema.object(properties: ["title": .string()], required: ["title"])
        let annotations: [String: FieldAnnotation] = [
            "title": FieldAnnotation(description: "The movie title exactly as written")
        ]
        let result = try PromptEngine.buildPrompt(userPrompt: "Extract", schema: schema, annotations: annotations)

        #expect(result.system.contains("The movie title exactly as written"))
        #expect(result.system.contains("Field guidance"))
    }

    @Test func examplesAppearInGuidance() throws {
        let schema = JSONSchema.object(properties: ["summary": .string()], required: ["summary"])
        let annotations: [String: FieldAnnotation] = [
            "summary": FieldAnnotation(examples: ["Great pacing", "Weak third act"])
        ]
        let result = try PromptEngine.buildPrompt(userPrompt: "Summarize", schema: schema, annotations: annotations)

        #expect(result.system.contains("Great pacing"))
        #expect(result.system.contains("Weak third act"))
    }

    @Test func emptyAnnotationsNoGuidance() throws {
        let schema = JSONSchema.object(properties: ["x": .string()], required: ["x"])
        let result = try PromptEngine.buildPrompt(userPrompt: "test", schema: schema)
        #expect(!result.system.contains("Field guidance"))
    }

    @Test func containsJSONInstruction() throws {
        let schema = JSONSchema.object()
        let result = try PromptEngine.buildPrompt(userPrompt: "test", schema: schema)
        #expect(result.system.contains("valid JSON"))
    }

    @Test func extractionPromptWrapsTextInDelimiters() throws {
        let schema = JSONSchema.object()
        let source = "Invoice #4242 — total due $19.99"
        let result = try PromptEngine.buildExtractionPrompt(
            text: source,
            instruction: "Extract the invoice number and total.",
            schema: schema
        )

        // Per-call nonce: assert structural shape rather than literal text.
        // UUIDs are hex with hyphens: 8-4-4-4-12. Match case-insensitively
        // since `UUID().uuidString` casing isn't a documented guarantee.
        let openPattern = #/<<<SOURCE-([0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12})>>>/#
        let closePattern =
            #/<<<END-SOURCE-([0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12})>>>/#

        guard
            let openMatch = result.user.firstMatch(of: openPattern),
            let closeMatch = result.user.firstMatch(of: closePattern),
            let sourceRange = result.user.range(of: source)
        else {
            Issue.record("Expected nonced delimiters and source text in user prompt")
            return
        }
        // Same nonce on both fences so the model can pair them.
        #expect(openMatch.output.1 == closeMatch.output.1)
        #expect(openMatch.range.upperBound <= sourceRange.lowerBound)
        #expect(sourceRange.upperBound <= closeMatch.range.lowerBound)
    }

    @Test func extractionDelimiterNonceIsPerCall() throws {
        let schema = JSONSchema.object()
        let pattern = #/<<<SOURCE-([0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12})>>>/#
        let first = try PromptEngine.buildExtractionPrompt(text: "x", instruction: "Extract.", schema: schema)
        let second = try PromptEngine.buildExtractionPrompt(text: "x", instruction: "Extract.", schema: schema)

        guard
            let firstNonce = first.user.firstMatch(of: pattern)?.output.1,
            let secondNonce = second.user.firstMatch(of: pattern)?.output.1
        else {
            Issue.record("Expected nonced delimiters in both prompts")
            return
        }
        #expect(firstNonce != secondNonce)
    }

    @Test func extractionPromptIncludesInstruction() throws {
        let schema = JSONSchema.object()
        let instruction = "Extract the invoice number and total in USD."
        let result = try PromptEngine.buildExtractionPrompt(
            text: "irrelevant",
            instruction: instruction,
            schema: schema
        )
        #expect(result.user.contains(instruction))
    }

    @Test func extractionPromptDiscouragesInvention() throws {
        let schema = JSONSchema.object()
        let result = try PromptEngine.buildExtractionPrompt(
            text: "irrelevant",
            instruction: "Extract.",
            schema: schema
        )
        #expect(result.system.lowercased().contains("do not invent"))
        #expect(result.system.contains("null"))
    }

    @Test func extractionPromptIncludesSchema() throws {
        let schema = JSONSchema.object(
            properties: ["invoiceNumber": .string(), "totalUSD": .number()],
            required: ["invoiceNumber", "totalUSD"]
        )
        let result = try PromptEngine.buildExtractionPrompt(
            text: "irrelevant",
            instruction: "Extract.",
            schema: schema
        )
        #expect(result.system.contains("JSON Schema"))
        #expect(result.system.contains("invoiceNumber"))
        #expect(result.system.contains("totalUSD"))
    }

    @Test func extractionPromptCustomSystemOverride() throws {
        let schema = JSONSchema.object()
        let result = try PromptEngine.buildExtractionPrompt(
            text: "irrelevant",
            instruction: "Extract.",
            schema: schema,
            system: "Custom extraction system."
        )
        #expect(result.system == "Custom extraction system.")
    }
}
