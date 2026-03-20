import Testing

@testable import Cast

enum TestSentiment: String, CastEnum {
    case positive, negative, neutral
}

@Suite("Classify")
struct ClassifyTests {

    @Test("classify throws modelNotLoaded when no model")
    func classifyNoModel() async {
        let model = CastModel(_testContainer: nil)
        await #expect(throws: CastError.self) {
            try await model.classify("test", as: TestSentiment.self)
        }
    }

    @Test("classification prompt includes enum values")
    func classificationPromptValues() {
        let values = ["positive", "negative", "neutral"]
        let result = PromptEngine.buildClassificationPrompt(
            userPrompt: "This is great!",
            enumValues: values
        )
        #expect(result.system.contains("positive"))
        #expect(result.system.contains("negative"))
        #expect(result.system.contains("neutral"))
    }

    @Test("classification uses custom system prompt when provided")
    func customSystemPrompt() {
        let custom = "Custom classifier"
        let result = PromptEngine.buildClassificationPrompt(
            userPrompt: "test",
            enumValues: ["a", "b"],
            system: custom
        )
        #expect(result.system == custom)
    }

    @Test("classification prompt passes user prompt through")
    func userPromptPassthrough() {
        let result = PromptEngine.buildClassificationPrompt(
            userPrompt: "analyze this text",
            enumValues: ["yes", "no"]
        )
        #expect(result.user == "analyze this text")
    }
}
