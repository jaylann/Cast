import Foundation

/// Output format for ``BenchmarkResult/formatted(as:)`` and
/// ``BenchmarkComparison/formatted(as:)``.
public enum OutputFormat: Sendable {
    /// Fixed-width, human-readable plain-text table.
    case table
    /// GitHub-flavored Markdown table — paste into PR descriptions, READMEs, etc.
    case markdown
    /// Pretty-printed JSON — feed into dashboards or downstream analysis tools.
    case json
}

/// Aggregated metrics from a single ``CastBench/run(type:prompt:iterations:config:)`` call.
public struct BenchmarkResult: Sendable, Codable {
    /// Average tokens generated per wall-clock second across all iterations.
    public let tokensPerSecond: Double
    /// Average wall-clock latency per iteration.
    public let averageLatency: Duration
    /// Estimated grammar-masking overhead per token, in milliseconds.
    /// `0` when no unconstrained reference run was performed (e.g. ``CastBench/run(type:prompt:iterations:config:)``
    /// with `iterations < 2`, or when the unconstrained sidecar threw).
    public let grammarOverheadMs: Double
    /// Average number of generated tokens per iteration.
    public let averageTokenCount: Double
    /// Number of iterations used to compute the aggregates.
    public let iterations: Int

    public init(
        tokensPerSecond: Double,
        averageLatency: Duration,
        grammarOverheadMs: Double,
        averageTokenCount: Double,
        iterations: Int
    ) {
        self.tokensPerSecond = tokensPerSecond
        self.averageLatency = averageLatency
        self.grammarOverheadMs = grammarOverheadMs
        self.averageTokenCount = averageTokenCount
        self.iterations = iterations
    }

    /// Render the result in one of the supported ``OutputFormat`` options.
    public func formatted(as format: OutputFormat) -> String {
        switch format {
        case .table: BenchmarkFormatters.formatTable(self)
        case .markdown: BenchmarkFormatters.formatMarkdown(self)
        case .json: BenchmarkFormatters.formatJSON(self)
        }
    }
}

/// Side-by-side metrics from a ``CastBench/compare(type:prompt:iterations:config:)`` call.
public struct BenchmarkComparison: Sendable, Codable {
    /// Aggregates from the constrained (Cast) generation path.
    public let constrained: BenchmarkResult
    /// Aggregates from the unconstrained (raw `MLXLMCommon.generate`) path.
    public let unconstrained: BenchmarkResult
    /// `(constrained.avgLatencyS - unconstrained.avgLatencyS) / unconstrained.avgLatencyS * 100`.
    /// Expressed as a percentage; `0` when the unconstrained run reported zero latency.
    public let overheadPercent: Double
    /// Fraction of unconstrained iterations whose raw output decoded successfully into `T`
    /// without ``JSONRepair``. `0.0` when no iterations succeeded; `1.0` when all did.
    public let unconstrainedValidRate: Double

    public init(
        constrained: BenchmarkResult,
        unconstrained: BenchmarkResult,
        overheadPercent: Double,
        unconstrainedValidRate: Double
    ) {
        self.constrained = constrained
        self.unconstrained = unconstrained
        self.overheadPercent = overheadPercent
        self.unconstrainedValidRate = unconstrainedValidRate
    }

    /// Render the comparison in one of the supported ``OutputFormat`` options.
    public func formatted(as format: OutputFormat) -> String {
        switch format {
        case .table: BenchmarkFormatters.formatTable(self)
        case .markdown: BenchmarkFormatters.formatMarkdown(self)
        case .json: BenchmarkFormatters.formatJSON(self)
        }
    }
}

/// Tok/s, latency, and grammar-overhead benchmarking for a loaded ``CastModel``.
///
/// ```swift
/// @Castable struct Person { var name: String = ""; var age: Int = 0 }
///
/// let model = try await CastModel.load("mlx-community/Llama-3.2-1B-Instruct-4bit")
/// let bench = CastBench(model)
///
/// let result = try await bench.run(type: Person.self, prompt: "Marie Curie, 66.", iterations: 5)
/// print(result.formatted(as: .markdown))
///
/// let comparison = try await bench.compare(type: Person.self, prompt: "Marie Curie, 66.", iterations: 5)
/// print(comparison.formatted(as: .markdown))
/// ```
///
/// `CastBench` is a thin orchestrator: it loops the requested number of
/// iterations, captures wall-clock latency and token counts, and aggregates
/// them. ``compare(type:prompt:iterations:config:)`` additionally runs an
/// unconstrained pass (no ``GrammarMaskedLogitProcessor``) and reports how
/// often the raw output happened to decode into `T` without ``JSONRepair``.
public struct CastBench: Sendable {
    /// The model under test.
    public let model: CastModel

    /// Wrap a loaded ``CastModel`` for benchmarking. The model must already be
    /// loaded; calls throw ``CastError/modelNotLoaded`` otherwise.
    public init(_ model: CastModel) {
        self.model = model
    }

    /// Benchmark the constrained-generation path.
    ///
    /// Loops `iterations` times, capturing wall-clock latency and generated
    /// token count for each call. Aggregates are means over all iterations.
    ///
    /// When `iterations >= 2`, runs a single unconstrained shadow pass to
    /// estimate ``BenchmarkResult/grammarOverheadMs``. With fewer iterations
    /// the shadow pass is skipped and the field is reported as `0` — the
    /// signal would be too noisy from a single sample.
    ///
    /// - Parameters:
    ///   - type: Output type — must be `Decodable & Sendable`. Typically a
    ///     `@Castable` struct.
    ///   - prompt: User prompt to drive each iteration.
    ///   - iterations: Number of iterations to time. Must be >= 1.
    ///   - config: Sampling, timeout, and JSON-repair knobs forwarded to each
    ///     iteration's ``CastModel/cast(_:as:system:config:didGenerate:)-2yyul`` call.
    /// - Returns: Aggregated ``BenchmarkResult``.
    /// - Throws: ``CastError`` from the underlying generation call. The first
    ///   failing iteration aborts the run.
    public func run(
        type: (some Decodable & Sendable).Type,
        prompt: String,
        iterations: Int,
        config: CastConfiguration = CastConfiguration()
    ) async throws -> BenchmarkResult {
        precondition(iterations >= 1, "CastBench.run requires iterations >= 1")

        var latencies: [Duration] = []
        var tokenCounts: [Int] = []
        latencies.reserveCapacity(iterations)
        tokenCounts.reserveCapacity(iterations)

        for _ in 0 ..< iterations {
            let sample = try await BenchmarkInstrumentation.runConstrainedIteration(
                model: model,
                type: type,
                prompt: prompt,
                config: config
            )
            latencies.append(sample.latency)
            tokenCounts.append(sample.tokenCount)
        }

        let constrained = aggregate(
            latencies: latencies,
            tokenCounts: tokenCounts,
            iterations: iterations,
            grammarOverheadMs: 0
        )

        guard iterations >= 2 else {
            return constrained
        }

        let overheadMs = await (try? measureGrammarOverhead(
            type: type,
            prompt: prompt,
            config: config,
            constrained: constrained
        )) ?? 0

        return BenchmarkResult(
            tokensPerSecond: constrained.tokensPerSecond,
            averageLatency: constrained.averageLatency,
            grammarOverheadMs: overheadMs,
            averageTokenCount: constrained.averageTokenCount,
            iterations: constrained.iterations
        )
    }

    /// Benchmark constrained vs. unconstrained generation side by side.
    ///
    /// Runs `iterations` constrained calls and `iterations` unconstrained
    /// calls (no ``GrammarMaskedLogitProcessor``). Reports both aggregates,
    /// the per-token overhead percentage, and the fraction of unconstrained
    /// outputs that decoded into `T` without ``JSONRepair`` — a rough proxy
    /// for "how much does the grammar actually buy you on this prompt?".
    ///
    /// - Parameters:
    ///   - type: Output type — must be `Decodable & Sendable`.
    ///   - prompt: User prompt to drive each iteration.
    ///   - iterations: Number of iterations *per side*. Must be >= 1.
    ///   - config: Sampling, timeout, and JSON-repair knobs forwarded to both
    ///     paths. The unconstrained path always ignores
    ///     ``CastConfiguration/repairTruncatedJSON`` — we measure the raw
    ///     decode rate.
    /// - Returns: Aggregated ``BenchmarkComparison``.
    /// - Throws: ``CastError`` from the constrained path. The unconstrained
    ///   path's per-iteration decode failures are *not* thrown — they become
    ///   ``BenchmarkComparison/unconstrainedValidRate``.
    public func compare(
        type: (some Decodable & Sendable).Type,
        prompt: String,
        iterations: Int,
        config: CastConfiguration = CastConfiguration()
    ) async throws -> BenchmarkComparison {
        precondition(iterations >= 1, "CastBench.compare requires iterations >= 1")

        var constrainedLatencies: [Duration] = []
        var constrainedTokens: [Int] = []
        constrainedLatencies.reserveCapacity(iterations)
        constrainedTokens.reserveCapacity(iterations)

        for _ in 0 ..< iterations {
            let sample = try await BenchmarkInstrumentation.runConstrainedIteration(
                model: model,
                type: type,
                prompt: prompt,
                config: config
            )
            constrainedLatencies.append(sample.latency)
            constrainedTokens.append(sample.tokenCount)
        }

        var unconstrainedLatencies: [Duration] = []
        var unconstrainedTokens: [Int] = []
        var validCount = 0
        unconstrainedLatencies.reserveCapacity(iterations)
        unconstrainedTokens.reserveCapacity(iterations)

        for _ in 0 ..< iterations {
            let sample = try await BenchmarkInstrumentation.runUnconstrainedIteration(
                model: model,
                type: type,
                prompt: prompt,
                config: config
            )
            unconstrainedLatencies.append(sample.latency)
            unconstrainedTokens.append(sample.tokenCount)
            if sample.decoded != nil {
                validCount += 1
            }
        }

        let constrained = aggregate(
            latencies: constrainedLatencies,
            tokenCounts: constrainedTokens,
            iterations: iterations,
            grammarOverheadMs: 0
        )
        let unconstrained = aggregate(
            latencies: unconstrainedLatencies,
            tokenCounts: unconstrainedTokens,
            iterations: iterations,
            grammarOverheadMs: 0
        )

        let constrainedMsPerTok = msPerToken(latency: constrained.averageLatency, tokens: constrained.averageTokenCount)
        let unconstrainedMsPerTok = msPerToken(
            latency: unconstrained.averageLatency,
            tokens: unconstrained.averageTokenCount
        )
        let perTokenOverheadMs = max(0, constrainedMsPerTok - unconstrainedMsPerTok)

        let constrainedSeconds = seconds(of: constrained.averageLatency)
        let unconstrainedSeconds = seconds(of: unconstrained.averageLatency)
        let overheadPct: Double = unconstrainedSeconds > 0
            ? (constrainedSeconds - unconstrainedSeconds) / unconstrainedSeconds * 100
            : 0

        let constrainedWithOverhead = BenchmarkResult(
            tokensPerSecond: constrained.tokensPerSecond,
            averageLatency: constrained.averageLatency,
            grammarOverheadMs: perTokenOverheadMs,
            averageTokenCount: constrained.averageTokenCount,
            iterations: constrained.iterations
        )

        return BenchmarkComparison(
            constrained: constrainedWithOverhead,
            unconstrained: unconstrained,
            overheadPercent: overheadPct,
            unconstrainedValidRate: Double(validCount) / Double(iterations)
        )
    }

    // MARK: - Private

    private func measureGrammarOverhead(
        type: (some Decodable & Sendable).Type,
        prompt: String,
        config: CastConfiguration,
        constrained: BenchmarkResult
    ) async throws -> Double {
        let sample = try await BenchmarkInstrumentation.runUnconstrainedIteration(
            model: model,
            type: type,
            prompt: prompt,
            config: config
        )
        let constrainedMsPerTok = msPerToken(
            latency: constrained.averageLatency,
            tokens: constrained.averageTokenCount
        )
        let unconstrainedMsPerTok = msPerToken(
            latency: sample.latency,
            tokens: Double(sample.tokenCount)
        )
        return max(0, constrainedMsPerTok - unconstrainedMsPerTok)
    }

    private func aggregate(
        latencies: [Duration],
        tokenCounts: [Int],
        iterations: Int,
        grammarOverheadMs: Double
    ) -> BenchmarkResult {
        let totalSeconds = latencies.reduce(0.0) { $0 + seconds(of: $1) }
        let avgSeconds = totalSeconds / Double(iterations)
        let avgLatency = Duration.seconds(avgSeconds)

        let totalTokens = tokenCounts.reduce(0, +)
        let avgTokens = Double(totalTokens) / Double(iterations)

        let tokensPerSecond: Double = avgSeconds > 0 ? avgTokens / avgSeconds : 0

        return BenchmarkResult(
            tokensPerSecond: tokensPerSecond,
            averageLatency: avgLatency,
            grammarOverheadMs: grammarOverheadMs,
            averageTokenCount: avgTokens,
            iterations: iterations
        )
    }

    private func seconds(of duration: Duration) -> Double {
        let comps = duration.components
        return Double(comps.seconds) + Double(comps.attoseconds) / 1e18
    }

    private func msPerToken(latency: Duration, tokens: Double) -> Double {
        guard tokens > 0 else { return 0 }
        return seconds(of: latency) * 1000.0 / tokens
    }
}
