import Testing

@testable import Cast

@Suite("GrammarProcessorCache")
struct CacheTests {

    @Test("prepare throws modelNotLoaded when no model")
    func prepareNoModel() async {
        let model = CastModel(_testContainer: nil)
        await #expect(throws: CastError.self) {
            try await model.prepare(String.self)
        }
    }

    @Test("cache clears without error")
    func cacheClear() async {
        let cache = GrammarProcessorCache()
        await cache.clear()
    }
}
