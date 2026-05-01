// File rationale: every blocking generation entrypoint on `CastModel`.
// Owns: `cast(_:as:…)`, `castJSON(_:…)`, `classify(_:…)`.
// Doesn't own: streaming (see `CastModel+Stream.swift`) or the
// extraction-flavored prompt (see `CastModel+Extract.swift`).

import Foundation
import JSONSchema
import MLX
@preconcurrency import MLXLMCommon
@preconcurrency import MLXStructured

public extension CastModel {
    /// Generate JSON that decodes into `T`. The schema is derived from `T`
    /// (with any `@Castable` annotations); the constrained sampler guarantees
    /// the model's output parses.
    ///
    /// ```swift
    /// @Castable struct Recipe { var title: String = ""; var minutes: Int = 0 }
    /// let r: Recipe = try await model.cast("Quick weeknight pasta")
    /// ```
    ///
    /// - Parameters:
    ///   - prompt: User prompt.
    ///   - type: Target type. Usually inferred.
    ///   - system: Optional system message prepended to the auto-built prompt.
    ///   - config: Sampling, timeout, and JSON-repair knobs.
    ///   - didGenerate: Optional per-token hook returning `.stop` to end early.
    /// - Throws: ``CastError/timedOut(partialOutput:)`` on
    ///   ``CastConfiguration/timeout`` expiry, ``CastError/cancelled(partialOutput:)``
    ///   on `Task.cancel()`, ``CastError/repairFailed(rawOutput:reason:)``
    ///   when partial output cannot be repaired, ``CastError/decodingFailed(rawOutput:error:)``
    ///   when (possibly repaired) JSON does not decode into `T`.
    /// - SeeAlso: ``CastModel/castStream(_:as:system:config:)`` for the
    ///   streaming variant that yields ``PartialResult`` snapshots as fields fill in.
    func cast<T: Decodable & Sendable>(
        _ prompt: String,
        as type: T.Type = T.self,
        system: String? = nil,
        config: CastConfiguration = CastConfiguration(),
        didGenerate: (@Sendable (Int) -> GenerateDisposition)? = nil
    ) async throws -> T {
        let schema: JSONSchema
        let annotations: [String: FieldAnnotation]
        do {
            schema = try SchemaGenerator.schema(for: type)
            annotations = try SchemaGenerator.annotations(for: type)
        } catch {
            throw CastError.schemaGenerationFailed(error.localizedDescription)
        }

        let built = PromptEngine.buildPrompt(
            userPrompt: prompt,
            schema: schema,
            annotations: annotations,
            system: system
        )

        return try await cast(
            built.user,
            as: type,
            schema: schema,
            system: built.system,
            config: config,
            didGenerate: didGenerate
        )
    }

    /// Return raw JSON (un-decoded, un-repaired) with the schema derived from
    /// `type`. Use when you want to inspect the model's bytes verbatim or do
    /// custom decoding. ``CastConfiguration/repairTruncatedJSON`` does *not*
    /// apply here — by contract, callers asked for raw output.
    func castJSON(
        _ prompt: String,
        schema type: (some Decodable & Sendable).Type,
        system: String? = nil,
        config: CastConfiguration = CastConfiguration(),
        didGenerate: (@Sendable (Int) -> GenerateDisposition)? = nil
    ) async throws -> String {
        let schema: JSONSchema
        let annotations: [String: FieldAnnotation]
        do {
            schema = try SchemaGenerator.schema(for: type)
            annotations = try SchemaGenerator.annotations(for: type)
        } catch {
            throw CastError.schemaGenerationFailed(error.localizedDescription)
        }

        let built = PromptEngine.buildPrompt(
            userPrompt: prompt,
            schema: schema,
            annotations: annotations,
            system: system
        )

        return try await castJSON(
            built.user,
            schema: schema,
            system: built.system,
            config: config,
            didGenerate: didGenerate
        )
    }

    /// Return raw JSON constrained to an explicit ``JSONSchema``. Skips
    /// auto-schema generation; useful when you have a hand-written schema
    /// or one shared between multiple types.
    func castJSON(
        _ prompt: String,
        schema: JSONSchema,
        system: String? = nil,
        config: CastConfiguration = CastConfiguration(),
        didGenerate: (@Sendable (Int) -> GenerateDisposition)? = nil
    ) async throws -> String {
        Self.ensureErrorHandler()

        guard let container else {
            throw CastError.modelNotLoaded
        }

        let grammar: Grammar
        do {
            grammar = try Grammar.schema(schema)
        } catch {
            throw CastError.schemaGenerationFailed(error.localizedDescription)
        }

        let fullPrompt: String = if let system {
            "\(system)\n\n\(prompt)"
        } else {
            prompt
        }

        let parameters = config.generateParameters

        let result: GenerateResult
        do {
            result = try await withInFlightRegistration {
                try await withGenerationTimeout(config.timeout) {
                    try await container.perform { context in
                        let userInput = UserInput(prompt: fullPrompt)
                        let lmInput = try await context.processor.prepare(input: userInput)

                        return try await MLXStructured.generate(
                            input: lmInput,
                            parameters: parameters,
                            context: context,
                            grammar: grammar,
                            didGenerate: { tokens in
                                if let didGenerate, didGenerate(tokens.count) == .stop {
                                    return .stop
                                }
                                return Task.isCancelled ? .stop : .more
                            }
                        )
                    }
                }
            }
        } catch let error as CastError {
            cleanupGPU()
            throw error
        } catch is CancellationError {
            cleanupGPU()
            throw CastError.cancelled(partialOutput: nil)
        } catch {
            cleanupGPU()
            throw CastError.generationFailed(error.localizedDescription)
        }

        cleanupGPU()

        if let globalError = Self.checkAndClearMLXGlobalError() {
            throw CastError.generationFailed(globalError)
        }

        if Task.isCancelled {
            throw CastError.cancelled(partialOutput: result.output)
        }

        return result.output
    }

    /// Decode into `T` using an explicit ``JSONSchema`` instead of the one
    /// the macro would synthesize. Useful for shared / hand-written schemas
    /// or when `T` is a generic container whose schema you build at runtime.
    func cast<T: Decodable>(
        _ prompt: String,
        as _: T.Type = T.self,
        schema: JSONSchema,
        system: String? = nil,
        config: CastConfiguration = CastConfiguration(),
        didGenerate: (@Sendable (Int) -> GenerateDisposition)? = nil
    ) async throws -> T {
        Self.ensureErrorHandler()

        guard let container else {
            throw CastError.modelNotLoaded
        }

        let grammar: Grammar
        do {
            grammar = try Grammar.schema(schema)
        } catch {
            throw CastError.schemaGenerationFailed(error.localizedDescription)
        }

        let fullPrompt: String = if let system {
            "\(system)\n\n\(prompt)"
        } else {
            prompt
        }

        let parameters = config.generateParameters

        let result: GenerateResult
        do {
            result = try await withInFlightRegistration {
                try await withGenerationTimeout(config.timeout) {
                    try await container.perform { context in
                        let userInput = UserInput(prompt: fullPrompt)
                        let lmInput = try await context.processor.prepare(input: userInput)

                        return try await MLXStructured.generate(
                            input: lmInput,
                            parameters: parameters,
                            context: context,
                            grammar: grammar,
                            didGenerate: { tokens in
                                if let didGenerate, didGenerate(tokens.count) == .stop {
                                    return .stop
                                }
                                return Task.isCancelled ? .stop : .more
                            }
                        )
                    }
                }
            }
        } catch let error as CastError {
            cleanupGPU()
            throw error
        } catch is CancellationError {
            cleanupGPU()
            throw CastError.cancelled(partialOutput: nil)
        } catch {
            cleanupGPU()
            throw CastError.generationFailed(error.localizedDescription)
        }

        cleanupGPU()

        if let globalError = Self.checkAndClearMLXGlobalError() {
            throw CastError.generationFailed(globalError)
        }

        if Task.isCancelled {
            throw CastError.cancelled(partialOutput: result.output)
        }

        let decodeInput: String
        if config.repairTruncatedJSON {
            switch JSONRepair.repair(result.output) {
            case let .ok(value):
                decodeInput = value
            case let .repaired(value, _):
                decodeInput = value
            case let .unrecoverable(reason):
                throw CastError.repairFailed(rawOutput: result.output, reason: reason)
            }
        } else {
            decodeInput = result.output
        }

        do {
            return try ValidatorSupport.decode(T.self, from: Data(decodeInput.utf8))
        } catch {
            throw CastError.decodingFailed(
                rawOutput: decodeInput,
                error: error.localizedDescription
            )
        }
    }

    /// Classify `prompt` into one of the cases of a ``CastEnum`` with a
    /// `String` raw value. Optimized for short outputs: `maxTokens` is
    /// capped at `10` and `temperature` is forced to `0`.
    ///
    /// ```swift
    /// enum Sentiment: String, CastEnum { case positive, negative, neutral }
    /// let s: Sentiment = try await model.classify("Best burrito in town.")
    /// ```
    func classify<T: CastEnum>(
        _ prompt: String,
        as type: T.Type = T.self,
        system: String? = nil,
        config: CastConfiguration? = nil,
        didGenerate: (@Sendable (Int) -> GenerateDisposition)? = nil
    ) async throws -> T where T.RawValue == String {
        let schema = T.castSchema
        let values = T.allCases.map(\.rawValue)

        let built = PromptEngine.buildClassificationPrompt(
            userPrompt: prompt,
            enumValues: values,
            system: system
        )

        var classifyConfig = config ?? CastConfiguration()
        classifyConfig.maxTokens = min(classifyConfig.maxTokens, 10)
        classifyConfig.temperature = 0.0

        return try await cast(
            built.user, as: type, schema: schema, system: built.system,
            config: classifyConfig, didGenerate: didGenerate
        )
    }

    /// Classify `prompt` into one of the cases of a ``CastEnum`` with an
    /// `Int` raw value. Same constraints as the `String` variant.
    func classify<T: CastEnum>(
        _ prompt: String,
        as type: T.Type = T.self,
        system: String? = nil,
        config: CastConfiguration? = nil,
        didGenerate: (@Sendable (Int) -> GenerateDisposition)? = nil
    ) async throws -> T where T.RawValue == Int {
        let schema = T.castSchema
        let values = T.allCases.map { String($0.rawValue) }

        let built = PromptEngine.buildClassificationPrompt(
            userPrompt: prompt,
            enumValues: values,
            system: system
        )

        var classifyConfig = config ?? CastConfiguration()
        classifyConfig.maxTokens = min(classifyConfig.maxTokens, 10)
        classifyConfig.temperature = 0.0

        return try await cast(
            built.user, as: type, schema: schema, system: built.system,
            config: classifyConfig, didGenerate: didGenerate
        )
    }
}
