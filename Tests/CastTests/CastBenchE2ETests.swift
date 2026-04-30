@testable import Cast
import Collections
import Foundation
import JSONSchema
import Testing

// MARK: - End-to-end CastBench tests

//
// Real model load + GPU work — gated by `.requiresMetal` so CI skips them.
// Uses iterations: 2 to keep runtime down. The 1B 4-bit Llama is the smallest
// model that ships from mlx-community.

private let benchE2EModelId = "mlx-community/Llama-3.2-1B-Instruct-4bit"

@Castable
private struct BenchPerson {
    var name: String = ""
    var age: Int = 0
}

@Test("CastBench.run produces non-zero throughput on a real model", .requiresMetal)
func benchRunE2E() async throws {
    let model = try await CastModel.load(benchE2EModelId)
    let bench = CastBench(model)

    var config = CastConfiguration()
    config.maxTokens = 64

    let result = try await bench.run(
        type: BenchPerson.self,
        prompt: "Marie Curie was a 66-year-old physicist.",
        iterations: 2,
        config: config
    )

    #expect(result.iterations == 2)
    #expect(result.tokensPerSecond > 0)
    #expect(result.averageTokenCount > 0)
}

@Test("CastBench.compare reports valid rate and overhead from a real model", .requiresMetal)
func benchCompareE2E() async throws {
    let model = try await CastModel.load(benchE2EModelId)
    let bench = CastBench(model)

    var config = CastConfiguration()
    config.maxTokens = 64

    let comparison = try await bench.compare(
        type: BenchPerson.self,
        prompt: "Marie Curie was a 66-year-old physicist.",
        iterations: 2,
        config: config
    )

    #expect(comparison.constrained.iterations == 2)
    #expect(comparison.unconstrained.iterations == 2)
    #expect(comparison.constrained.tokensPerSecond > 0)
    #expect(comparison.unconstrained.tokensPerSecond > 0)
    #expect(comparison.unconstrainedValidRate >= 0.0)
    #expect(comparison.unconstrainedValidRate <= 1.0)
}
