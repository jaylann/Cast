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
    /// honors `Task.cancel()` (surfaced as ``CastError/cancelled(partialOutput:)``
    /// carrying the last decoded snapshot, if any), and respects
    /// ``CastConfiguration/timeout``.
    ///
    /// Buffering uses ``AsyncThrowingStream/Continuation/BufferingPolicy/bufferingNewest(_:)``
    /// with bound `1`: a slow consumer paired with a fast model will see only
    /// the *most recent* snapshot at any time, not every intermediate one.
    /// Streaming UIs only care about the latest state, so this trades historical
    /// fidelity for a fixed memory ceiling. The terminal yield is the final
    /// write before `.finish()` and is therefore never dropped.
    func castStream<T: Castable>(
        _ prompt: String,
        as type: T.Type = T.self,
        system: String? = nil,
        config: CastConfiguration = CastConfiguration()
    ) -> AsyncThrowingStream<PartialResult<T>, Error> {
        // `bufferingNewest(1)` caps memory at one in-flight `PartialResult<T>`:
        // a slow consumer paired with a fast generation drops stale snapshots
        // instead of unbounded buffering. The terminal yield is the last write
        // before `.finish()` and is therefore never dropped.
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
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

        // Cross-isolation handle for the in-flight buffer so the cancellation
        // catch (outside the perform closure) can recover the partial bytes.
        let bufferHolder = StreamBufferHolder()
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
                        var lastProgress = 0.0

                        for try await chunk in stream {
                            if Task.isCancelled { break }
                            buffer.append(chunk.chunk)
                            lastTokenCount = chunk.totalTokens
                            bufferHolder.set(buffer)

                            if let snapshot = decodePartial(
                                T.self,
                                from: buffer,
                                tokenCount: lastTokenCount,
                                maxTokens: maxTokens,
                                minProgress: lastProgress
                            ) {
                                lastProgress = snapshot.progress
                                continuation.yield(snapshot)
                            }
                        }

                        // Cancellation must not be reported as a decode/repair
                        // failure: a half-formed buffer almost always fails
                        // `yieldTerminal`, masking the real cause. Surface the
                        // outer `Task.isCancelled` check below instead.
                        if Task.isCancelled { return }

                        try yieldTerminal(
                            T.self,
                            buffer: buffer,
                            tokenCount: lastTokenCount,
                            maxTokens: maxTokens,
                            minProgress: lastProgress,
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
            throw CastError.cancelled(partialOutput: bufferHolder.snapshot())
        } catch {
            cleanupGPU()
            throw CastError.generationFailed(error.localizedDescription)
        }

        cleanupGPU()

        if let globalError = Self.checkAndClearMLXGlobalError() {
            throw CastError.generationFailed(globalError)
        }

        if Task.isCancelled {
            throw CastError.cancelled(partialOutput: bufferHolder.snapshot())
        }
    }
}

/// Sendable bridge for the in-flight stream buffer. Lets the post-cancel
/// `catch` block recover the last bytes accumulated inside the perform
/// closure (which runs on a different actor) so they can ride along on
/// `CastError.cancelled(partialOutput:)`.
private final class StreamBufferHolder: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = ""

    func set(_ newValue: String) {
        lock.lock()
        defer { lock.unlock() }
        buffer = newValue
    }

    func snapshot() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return buffer.isEmpty ? nil : buffer
    }
}

private func decodePartial<T: Castable>(
    _: T.Type,
    from buffer: String,
    tokenCount: Int,
    maxTokens: Int,
    minProgress: Double
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

    let raw = min(Double(tokenCount) / Double(maxTokens), 1.0)
    let progress = max(raw, minProgress)
    return PartialResult<T>(value: value, progress: progress, tokenCount: tokenCount)
}

private func yieldTerminal<T: Castable>(
    _: T.Type,
    buffer: String,
    tokenCount: Int,
    maxTokens: Int,
    minProgress: Double,
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

    // The terminal yield must guarantee a fully-decoded value, matching
    // `cast()` semantics. `T.PartiallyGenerated` is all-Optional, so it
    // would silently accept a buffer with missing required fields (e.g. a
    // generation that hit `maxTokens` mid-object). Decode `T.self` first to
    // enforce the schema's required-field contract; only then project to
    // `PartiallyGenerated` for the consumer-facing type.
    let data = Data(decodeInput.utf8)
    let decoder = JSONDecoder()

    do {
        _ = try decoder.decode(T.self, from: data)
    } catch {
        throw CastError.decodingFailed(
            rawOutput: decodeInput,
            error: error.localizedDescription
        )
    }

    let value: T.PartiallyGenerated
    do {
        value = try decoder.decode(T.PartiallyGenerated.self, from: data)
    } catch {
        throw CastError.decodingFailed(
            rawOutput: decodeInput,
            error: error.localizedDescription
        )
    }

    let raw = min(Double(tokenCount) / Double(maxTokens), 1.0)
    let progress = max(raw, minProgress)
    continuation.yield(PartialResult<T>(value: value, progress: progress, tokenCount: tokenCount))
}
