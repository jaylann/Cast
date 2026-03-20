import Testing
@testable import Cast

@Test func testDefaultConfiguration() {
    let config = CastConfiguration()
    #expect(config.maxTokens == 1024)
    #expect(config.temperature == 0.7)
    #expect(config.topP == 0.9)
}

@Test func testCustomConfiguration() {
    let config = CastConfiguration(maxTokens: 512, temperature: 0.3, topP: 0.8)
    #expect(config.maxTokens == 512)
    #expect(config.temperature == 0.3)
    #expect(config.topP == 0.8)
}
