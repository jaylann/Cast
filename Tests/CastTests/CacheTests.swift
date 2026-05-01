@testable import Cast
import Foundation
@preconcurrency import MLXLMCommon
@preconcurrency import MLXStructured
import Testing

private actor LoaderCounter {
    private(set) var count = 0
    @discardableResult
    func bump() -> Int {
        count += 1
        return count
    }
}

@Suite("GrammarProcessorCache")
struct CacheTests {
    @Test("prepare throws modelNotLoaded when no model")
    func prepareNoModel() async {
        let model = CastModel(_testContainer: nil)
        await #expect(throws: CastError.self) {
            try await model.prepare(String.self)
        }
    }

    @Test("cache hit does not re-invoke loader")
    func cacheHitDoesNotReinvokeLoader() async throws {
        let counter = LoaderCounter()
        let cache = GrammarProcessorCache { _ in
            await counter.bump()
            return TokenizerArtifacts(vocab: ["a"], vocabType: 0, stopTokenIds: [])
        }
        let config = ModelConfiguration(id: "test/dummy")

        _ = try await cache.artifacts(for: config)
        _ = try await cache.artifacts(for: config)

        let count = await counter.count
        #expect(count == 1)
    }

    @Test("concurrent calls share one in-flight task")
    func concurrentCallsShareOneInflightTask() async throws {
        let counter = LoaderCounter()
        let cache = GrammarProcessorCache { _ in
            await counter.bump()
            try await Task.sleep(nanoseconds: 50_000_000)
            return TokenizerArtifacts(vocab: ["a"], vocabType: 0, stopTokenIds: [])
        }
        let config = ModelConfiguration(id: "test/dummy")

        async let first = cache.artifacts(for: config)
        async let second = cache.artifacts(for: config)
        let results = try await (first, second)

        let count = await counter.count
        #expect(count == 1)
        #expect(results.0.vocab == results.1.vocab)
    }

    @Test("failure path clears in-flight so next call retries")
    func failurePathClearsInflight() async throws {
        let counter = LoaderCounter()
        let cache = GrammarProcessorCache { _ in
            let invocation = await counter.bump()
            if invocation == 1 {
                throw CastError.generationFailed("boom")
            }
            return TokenizerArtifacts(vocab: ["b"], vocabType: 0, stopTokenIds: [])
        }
        let config = ModelConfiguration(id: "test/dummy")

        await #expect(throws: CastError.self) {
            _ = try await cache.artifacts(for: config)
        }

        let result = try await cache.artifacts(for: config)
        #expect(result.vocab == ["b"])

        let count = await counter.count
        #expect(count == 2)
    }

    @Test("warmUp populates cache (single loader invocation)")
    func warmUpPopulatesCache() async throws {
        let counter = LoaderCounter()
        let cache = GrammarProcessorCache { _ in
            await counter.bump()
            return TokenizerArtifacts(vocab: ["c"], vocabType: 0, stopTokenIds: [])
        }
        let config = ModelConfiguration(id: "test/dummy")

        try await cache.warmUp(for: config)
        _ = try await cache.artifacts(for: config)

        let count = await counter.count
        #expect(count == 1)
    }

    @Test("clear empties cache so next call re-invokes loader")
    func clearEmptiesCache() async throws {
        let counter = LoaderCounter()
        let cache = GrammarProcessorCache { _ in
            await counter.bump()
            return TokenizerArtifacts(vocab: ["d"], vocabType: 0, stopTokenIds: [])
        }
        let config = ModelConfiguration(id: "test/dummy")

        _ = try await cache.artifacts(for: config)
        await cache.clear()
        _ = try await cache.artifacts(for: config)

        let count = await counter.count
        #expect(count == 2)
    }
}
