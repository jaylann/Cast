@testable import Cast
import Foundation
import Testing

// MARK: - BenchmarkResult

@Test func benchmarkResultTokensPerSecondRoundtrip() {
    let result = BenchmarkResult(
        tokensPerSecond: 42.5,
        averageLatency: .milliseconds(500),
        grammarOverheadMs: 1.25,
        averageTokenCount: 21.25,
        iterations: 4
    )
    #expect(result.tokensPerSecond == 42.5)
    #expect(result.averageLatency == .milliseconds(500))
    #expect(result.iterations == 4)
}

@Test func benchmarkResultJSONRoundtrip() throws {
    let result = BenchmarkResult(
        tokensPerSecond: 100.0,
        averageLatency: .seconds(1),
        grammarOverheadMs: 2.5,
        averageTokenCount: 100.0,
        iterations: 3
    )
    let json = result.formatted(as: .json)
    let data = Data(json.utf8)
    let decoded = try JSONDecoder().decode(BenchmarkResult.self, from: data)
    #expect(decoded.tokensPerSecond == result.tokensPerSecond)
    #expect(decoded.averageLatency == result.averageLatency)
    #expect(decoded.grammarOverheadMs == result.grammarOverheadMs)
    #expect(decoded.averageTokenCount == result.averageTokenCount)
    #expect(decoded.iterations == result.iterations)
}

@Test func benchmarkResultMarkdownContainsHeaders() {
    let result = BenchmarkResult(
        tokensPerSecond: 50.0,
        averageLatency: .milliseconds(200),
        grammarOverheadMs: 0.5,
        averageTokenCount: 10.0,
        iterations: 5
    )
    let md = result.formatted(as: .markdown)
    #expect(md.contains("| Metric | Value |"))
    #expect(md.contains("| --- | --- |"))
    #expect(md.contains("Iterations"))
    #expect(md.contains("Tokens/sec"))
    #expect(md.contains("Grammar overhead"))
}

@Test func benchmarkResultTableColumnsAlign() {
    let result = BenchmarkResult(
        tokensPerSecond: 10.0,
        averageLatency: .milliseconds(100),
        grammarOverheadMs: 0.1,
        averageTokenCount: 1.0,
        iterations: 1
    )
    let table = result.formatted(as: .table)
    let lines = table.split(separator: "\n").map(String.init)
    let pipeLines = lines.filter { $0.hasPrefix("|") }
    let pipeCounts = Set(pipeLines.map { $0.count(where: { $0 == "|" }) })
    #expect(pipeCounts.count == 1, "Expected all pipe-prefixed lines to have the same column count, got \(pipeCounts)")

    let separatorLines = lines.filter { $0.hasPrefix("+") }
    let separatorWidths = Set(separatorLines.map(\.count))
    #expect(separatorWidths.count == 1, "Separator lines must all be the same width")

    let pipeRowWidths = Set(pipeLines.map(\.count))
    #expect(pipeRowWidths.count == 1, "Body rows must all be the same width")
}

// MARK: - BenchmarkComparison

@Test func benchmarkComparisonOverheadCalculation() {
    let constrained = BenchmarkResult(
        tokensPerSecond: 80.0,
        averageLatency: .milliseconds(125),
        grammarOverheadMs: 0.5,
        averageTokenCount: 10.0,
        iterations: 4
    )
    let unconstrained = BenchmarkResult(
        tokensPerSecond: 100.0,
        averageLatency: .milliseconds(100),
        grammarOverheadMs: 0,
        averageTokenCount: 10.0,
        iterations: 4
    )
    let expectedOverheadPct = (0.125 - 0.100) / 0.100 * 100
    let comparison = BenchmarkComparison(
        constrained: constrained,
        unconstrained: unconstrained,
        overheadPercent: expectedOverheadPct,
        unconstrainedValidRate: 0.5
    )
    #expect(abs(comparison.overheadPercent - 25.0) < 1e-9)
    #expect(comparison.unconstrainedValidRate >= 0.0 && comparison.unconstrainedValidRate <= 1.0)
}

@Test func benchmarkComparisonValidRateBounds() {
    let result = BenchmarkResult(
        tokensPerSecond: 1, averageLatency: .seconds(1),
        grammarOverheadMs: 0, averageTokenCount: 1, iterations: 1
    )
    let allValid = BenchmarkComparison(
        constrained: result, unconstrained: result,
        overheadPercent: 0, unconstrainedValidRate: 1.0
    )
    let noneValid = BenchmarkComparison(
        constrained: result, unconstrained: result,
        overheadPercent: 0, unconstrainedValidRate: 0.0
    )
    #expect(allValid.unconstrainedValidRate == 1.0)
    #expect(noneValid.unconstrainedValidRate == 0.0)
}

@Test func benchmarkComparisonJSONRoundtrip() throws {
    let result = BenchmarkResult(
        tokensPerSecond: 60, averageLatency: .milliseconds(250),
        grammarOverheadMs: 1.0, averageTokenCount: 15, iterations: 3
    )
    let comparison = BenchmarkComparison(
        constrained: result, unconstrained: result,
        overheadPercent: 5.0, unconstrainedValidRate: 0.66
    )
    let json = comparison.formatted(as: .json)
    let decoded = try JSONDecoder().decode(BenchmarkComparison.self, from: Data(json.utf8))
    #expect(decoded.overheadPercent == 5.0)
    #expect(decoded.unconstrainedValidRate == 0.66)
    #expect(decoded.constrained.iterations == 3)
}

@Test func benchmarkComparisonMarkdownHasThreeColumnHeader() {
    let result = BenchmarkResult(
        tokensPerSecond: 1, averageLatency: .seconds(1),
        grammarOverheadMs: 0, averageTokenCount: 1, iterations: 1
    )
    let comparison = BenchmarkComparison(
        constrained: result, unconstrained: result,
        overheadPercent: 10, unconstrainedValidRate: 0.75
    )
    let md = comparison.formatted(as: .markdown)
    #expect(md.contains("| Metric | Constrained | Unconstrained |"))
    #expect(md.contains("Overhead"))
    #expect(md.contains("Valid rate"))
}

@Test func benchmarkComparisonTableColumnsAlign() {
    let result = BenchmarkResult(
        tokensPerSecond: 10, averageLatency: .milliseconds(100),
        grammarOverheadMs: 0, averageTokenCount: 1, iterations: 2
    )
    let comparison = BenchmarkComparison(
        constrained: result, unconstrained: result,
        overheadPercent: 0, unconstrainedValidRate: 1.0
    )
    let table = comparison.formatted(as: .table)
    let lines = table.split(separator: "\n").map(String.init)

    let pipeLines = lines.filter { $0.hasPrefix("|") }
    let pipeCounts = Set(pipeLines.map { $0.count(where: { $0 == "|" }) })
    #expect(pipeCounts == [4], "3-column table rows expected 4 pipe characters per row, got \(pipeCounts)")

    let widths = Set(pipeLines.map(\.count))
    #expect(widths.count == 1, "All body rows must be the same width")
}

// MARK: - CastBench surface

@Test func castBenchInitialization() {
    let model = CastModel()
    let bench = CastBench(model)
    #expect(bench.model === model)
}

@Test func castBenchRunWithoutLoadedModelThrows() async throws {
    let bench = CastBench(CastModel())
    await #expect(throws: CastError.self) {
        _ = try await bench.run(type: SyntheticBenchPayload.self, prompt: "x", iterations: 1)
    }
}

@Test func castBenchCompareWithoutLoadedModelThrows() async throws {
    let bench = CastBench(CastModel())
    await #expect(throws: CastError.self) {
        _ = try await bench.compare(type: SyntheticBenchPayload.self, prompt: "x", iterations: 1)
    }
}

private struct SyntheticBenchPayload: Codable, Sendable {
    var label: String
    var score: Int
}
