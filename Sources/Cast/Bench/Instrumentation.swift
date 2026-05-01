import Foundation
import JSONSchema
@preconcurrency import MLXLMCommon

/// Per-iteration instrumentation helpers for ``CastBench``.
///
/// Both helpers capture wall-clock latency via `ContinuousClock`, the generated
/// token count via `didGenerate`, the raw output bytes, and a best-effort
/// strict decode (no ``JSONRepair``) of the output into `T`.
enum BenchmarkInstrumentation {
    /// Result of a single benchmark iteration.
    struct IterationSample: Sendable {
        let latency: Duration
        let tokenCount: Int
        let output: String
        /// `true` when the raw output decoded into `T` without ``JSONRepair``.
        /// `false` when decoding failed. Always `true` for the constrained path
        /// after grammar-masked generation.
        let decoded: Bool
    }

    /// Run one constrained iteration through ``CastModel/castJSON(_:schema:system:config:didGenerate:)-9eopl``.
    ///
    /// Latency is wall-clock between the call's entry and return. Token count
    /// is the maximum value seen by `didGenerate` — the underlying generate
    /// loop reports cumulative counts, so the last value is the total.
    static func runConstrainedIteration(
        model: CastModel,
        type: (some Decodable & Sendable).Type,
        prompt: String,
        config: CastConfiguration
    ) async throws -> IterationSample {
        let counter = TokenCounter()
        let clock = ContinuousClock()

        let start = clock.now
        let output = try await model.castJSON(
            prompt,
            schema: type,
            config: config,
            didGenerate: { count in
                counter.set(count)
                return .more
            }
        )
        let latency = clock.now - start

        let decoded = strictDecode(type, from: output)
        return IterationSample(
            latency: latency,
            tokenCount: counter.value,
            output: output,
            decoded: decoded
        )
    }

    /// Run one unconstrained iteration. Skips ``GrammarMaskedLogitProcessor``
    /// entirely by calling `MLXLMCommon.generate(...)` directly. Honors the
    /// in-flight registry so iOS background hooks still cancel cleanly.
    ///
    /// `decoded` reports whether the raw output happened to parse into `T` —
    /// the basis of ``BenchmarkComparison/unconstrainedValidRate``.
    static func runUnconstrainedIteration(
        model: CastModel,
        type: (some Decodable & Sendable).Type,
        prompt: String,
        config: CastConfiguration
    ) async throws -> IterationSample {
        guard let container = model.container else {
            throw CastError.modelNotLoaded
        }

        // Build the same auto-prompt the constrained path would use, so that
        // overhead numbers compare apples to apples. Surface schema-generation
        // failures as `CastError` for parity with `CastModel.cast(...)`.
        let schema: JSONSchema
        let annotations: [String: FieldAnnotation]
        do {
            schema = try SchemaGenerator.schema(for: type)
            annotations = try SchemaGenerator.annotations(for: type)
        } catch {
            throw CastError.schemaGenerationFailed(error.localizedDescription)
        }
        let built = try PromptEngine.buildPrompt(
            userPrompt: prompt,
            schema: schema,
            annotations: annotations,
            system: nil
        )
        let fullPrompt = "\(built.system)\n\n\(built.user)"

        let parameters = config.generateParameters
        let counter = TokenCounter()
        let clock = ContinuousClock()

        let start = clock.now
        let result: GenerateResult
        do {
            result = try await model.withInFlightRegistration {
                try await withGenerationTimeout(config.timeout) {
                    try await container.perform { context in
                        let userInput = UserInput(prompt: fullPrompt)
                        let lmInput = try await context.processor.prepare(input: userInput)
                        let iterator = try TokenIterator(
                            input: lmInput,
                            model: context.model,
                            parameters: parameters
                        )
                        return MLXLMCommon.generate(
                            input: lmInput,
                            context: context,
                            iterator: iterator,
                            didGenerate: { tokens in
                                counter.set(tokens.count)
                                return Task.isCancelled ? .stop : .more
                            }
                        )
                    }
                }
            }
        } catch let error as CastError {
            model.cleanupGPU()
            throw error
        } catch is CancellationError {
            model.cleanupGPU()
            throw CastError.cancelled(partialOutput: nil)
        } catch {
            model.cleanupGPU()
            throw CastError.generationFailed(error.localizedDescription)
        }
        let latency = clock.now - start

        model.cleanupGPU()

        if let globalError = CastModel.checkAndClearMLXGlobalError() {
            throw CastError.generationFailed(globalError)
        }
        if Task.isCancelled {
            throw CastError.cancelled(partialOutput: result.output)
        }

        let decoded = strictDecode(type, from: result.output)
        return IterationSample(
            latency: latency,
            tokenCount: counter.value,
            output: result.output,
            decoded: decoded
        )
    }

    /// Strict decode (no ``JSONRepair``) — used to compute
    /// ``BenchmarkComparison/unconstrainedValidRate``.
    private static func strictDecode<T: Decodable & Sendable>(
        _: T.Type,
        from raw: String
    ) -> Bool {
        do {
            _ = try JSONDecoder().decode(T.self, from: Data(raw.utf8))
            return true
        } catch {
            return false
        }
    }

    /// Fraction of `samples` whose `decoded` flag is `true`.
    ///
    /// Used by ``CastBench/compare(type:prompt:iterations:config:)`` to
    /// compute ``BenchmarkComparison/unconstrainedValidRate``. Returns `0`
    /// for an empty input — there's nothing to be valid against.
    static func validRate(of samples: [IterationSample]) -> Double {
        guard !samples.isEmpty else { return 0 }
        let valid = samples.reduce(into: 0) { count, sample in
            if sample.decoded { count += 1 }
        }
        return Double(valid) / Double(samples.count)
    }
}

/// Thread-safe cumulative token counter for `didGenerate` callbacks.
///
/// MLX's `didGenerate` reports the cumulative token list each step, so we
/// store the max count seen rather than incrementing.
private final class TokenCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    func set(_ count: Int) {
        lock.lock()
        _value = max(_value, count)
        lock.unlock()
    }
}
