import Foundation
import JSONSchema
import MLX
@preconcurrency import MLXLMCommon
@preconcurrency import MLXStructured

public extension CastModel {
    /// Stream `T.PartiallyGenerated` snapshots as the model fills in fields.
    ///
    /// Each yielded ``PartialResult`` carries a decoded snapshot, the running
    /// token count, and a `0...1` `progress` ratio against
    /// ``CastConfiguration/maxTokens``. Snapshots become available as soon as
    /// the in-flight bytes can be repaired into valid JSON; very early chunks
    /// (e.g. just `{`) are dropped silently. The final yield always carries
    /// the fully-decoded value.
    ///
    /// ```swift
    /// for try await partial in model.castStream("...", as: Recipe.self) {
    ///     ui.update(partial.value, progress: partial.progress)
    /// }
    /// ```
    ///
    /// The stream terminates with ``CastError`` on schema/generation failure,
    /// honors `Task.cancel()`, and respects ``CastConfiguration/timeout``.
    func castStream<T: Castable>(
        _ prompt: String,
        as type: T.Type = T.self,
        system: String? = nil,
        config: CastConfiguration = CastConfiguration()
    ) -> AsyncThrowingStream<PartialResult<T>, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await runStream(
                        prompt: prompt,
                        type: type,
                        system: system,
                        config: config,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func runStream<T: Castable>(
        prompt: String,
        type: T.Type,
        system: String?,
        config: CastConfiguration,
        continuation: AsyncThrowingStream<PartialResult<T>, Error>.Continuation
    ) async throws {
        Self.ensureErrorHandler()

        guard let container else {
            throw CastError.modelNotLoaded
        }

        let schema: JSONSchema
        do {
            schema = try SchemaGenerator.schema(for: type)
        } catch {
            throw CastError.schemaGenerationFailed(error.localizedDescription)
        }

        let annotations = (try? SchemaGenerator.annotations(for: type)) ?? [:]
        let built = PromptEngine.buildPrompt(
            userPrompt: prompt,
            schema: schema,
            annotations: annotations,
            system: system
        )

        let grammar: Grammar
        do {
            grammar = try Grammar.schema(schema)
        } catch {
            throw CastError.schemaGenerationFailed(error.localizedDescription)
        }

        let fullPrompt = "\(built.system)\n\n\(built.user)"
        let parameters = config.generateParameters
        let maxTokens = max(config.maxTokens, 1)

        do {
            try await withInFlightRegistration {
                try await withGenerationTimeout(config.timeout) {
                    try await container.perform { context in
                        let userInput = UserInput(prompt: fullPrompt)
                        let lmInput = try await context.processor.prepare(input: userInput)

                        let stream = try await MLXStructured.generateStream(
                            input: lmInput,
                            parameters: parameters,
                            context: context,
                            grammar: grammar
                        )

                        var buffer = ""
                        var lastTokenCount = 0

                        for try await chunk in stream {
                            if Task.isCancelled { break }
                            buffer.append(chunk.chunk)
                            lastTokenCount = chunk.totalTokens

                            if let snapshot = decodePartial(
                                T.self,
                                from: buffer,
                                tokenCount: lastTokenCount,
                                maxTokens: maxTokens
                            ) {
                                continuation.yield(snapshot)
                            }
                        }

                        try yieldTerminal(
                            T.self,
                            buffer: buffer,
                            tokenCount: lastTokenCount,
                            maxTokens: maxTokens,
                            config: config,
                            continuation: continuation
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
            throw CastError.cancelled(partialOutput: nil)
        }
    }
}

private func decodePartial<T: Castable>(
    _: T.Type,
    from buffer: String,
    tokenCount: Int,
    maxTokens: Int
) -> PartialResult<T>? {
    let candidate: String
    switch JSONRepair.repair(buffer) {
    case let .ok(value):
        candidate = value
    case let .repaired(value, _):
        candidate = value
    case .unrecoverable:
        return nil
    }

    guard let value = try? JSONDecoder().decode(
        T.PartiallyGenerated.self,
        from: Data(candidate.utf8)
    ) else {
        return nil
    }

    let progress = min(Double(tokenCount) / Double(maxTokens), 1.0)
    return PartialResult<T>(value: value, progress: progress, tokenCount: tokenCount)
}

private func yieldTerminal<T: Castable>(
    _: T.Type,
    buffer: String,
    tokenCount: Int,
    maxTokens: Int,
    config: CastConfiguration,
    continuation: AsyncThrowingStream<PartialResult<T>, Error>.Continuation
) throws {
    let decodeInput: String
    if config.repairTruncatedJSON {
        switch JSONRepair.repair(buffer) {
        case let .ok(value):
            decodeInput = value
        case let .repaired(value, _):
            decodeInput = value
        case let .unrecoverable(reason):
            throw CastError.repairFailed(rawOutput: buffer, reason: reason)
        }
    } else {
        decodeInput = buffer
    }

    let value: T.PartiallyGenerated
    do {
        value = try JSONDecoder().decode(
            T.PartiallyGenerated.self,
            from: Data(decodeInput.utf8)
        )
    } catch {
        throw CastError.decodingFailed(
            rawOutput: decodeInput,
            error: error.localizedDescription
        )
    }

    let progress = min(Double(tokenCount) / Double(maxTokens), 1.0)
    continuation.yield(PartialResult<T>(value: value, progress: progress, tokenCount: tokenCount))
}
