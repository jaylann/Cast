@testable import Cast
import JSONSchema
import Testing

@Suite("PromptEngine throws on un-encodable schemas")
struct PromptEngineThrowsTests {
    /// `JSONEncoder` defaults to `.throw` for non-conforming floats, so a
    /// schema with `Double.nan` as a numeric constant trips the encode path
    /// without needing to widen the public API.
    @Test func buildPromptThrowsSchemaGenerationFailedOnNaNMinimum() {
        let schema = JSONSchema.number(minimum: .nan)
        #expect(throws: CastError.self) {
            _ = try PromptEngine.buildPrompt(userPrompt: "test", schema: schema)
        }
        do {
            _ = try PromptEngine.buildPrompt(userPrompt: "test", schema: schema)
            Issue.record("Expected buildPrompt to throw on NaN minimum")
        } catch let CastError.schemaGenerationFailed(detail) {
            #expect(detail.contains("schema") || detail.contains("UTF-8") || !detail.isEmpty)
        } catch {
            Issue.record("Expected CastError.schemaGenerationFailed, got \(error)")
        }
    }

    @Test func buildExtractionPromptThrowsSchemaGenerationFailedOnNaNMinimum() {
        let schema = JSONSchema.number(minimum: .nan)
        #expect(throws: CastError.self) {
            _ = try PromptEngine.buildExtractionPrompt(
                text: "irrelevant",
                instruction: "Extract.",
                schema: schema
            )
        }
        do {
            _ = try PromptEngine.buildExtractionPrompt(
                text: "irrelevant",
                instruction: "Extract.",
                schema: schema
            )
            Issue.record("Expected buildExtractionPrompt to throw on NaN minimum")
        } catch let CastError.schemaGenerationFailed(detail) {
            #expect(detail.contains("schema") || detail.contains("UTF-8") || !detail.isEmpty)
        } catch {
            Issue.record("Expected CastError.schemaGenerationFailed, got \(error)")
        }
    }
}
