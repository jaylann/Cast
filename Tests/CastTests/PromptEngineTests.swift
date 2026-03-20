import Testing
import JSONSchema
@testable import Cast

@Suite("PromptEngine")
struct PromptEngineTests {

    @Test func defaultSystemIncludesSchema() throws {
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
}
