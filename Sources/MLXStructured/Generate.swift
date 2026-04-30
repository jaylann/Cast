//
//  Generate.swift
//  MLXStructured
//
//  Created by Ivan Petrukha on 27.09.2025.
//
// Modifications: add Grammar-input chunk stream by Justin Lanfermann, 2026

import Foundation
import JSONSchema
import MLX
import MLXLMCommon

#if canImport(FoundationModels)
    import FoundationModels
#endif

public func generate(
    input: LMInput,
    parameters: GenerateParameters = GenerateParameters(),
    context: ModelContext,
    grammar: Grammar,
    didGenerate: ([Int]) -> GenerateDisposition = { _ in .more }
) async throws -> GenerateResult {
    let sampler = parameters.sampler()
    let processor = try await GrammarMaskedLogitProcessor.from(configuration: context.configuration, grammar: grammar)
    let iterator = try TokenIterator(input: input, model: context.model, processor: processor, sampler: sampler)
    return generate(input: input, context: context, iterator: iterator, didGenerate: didGenerate)
}

/// One incremental yield from ``generateStream(input:parameters:context:grammar:)``.
public struct GrammarChunk: Sendable {
    public let chunk: String
    public let totalTokens: Int

    public init(chunk: String, totalTokens: Int) {
        self.chunk = chunk
        self.totalTokens = totalTokens
    }
}

/// Drive a constrained generation and stream decoded text chunks as they arrive,
/// alongside the running token count. The stream finishes when the model stops
/// (EOS, max tokens, or downstream cancellation of the consuming task).
public func generateStream(
    input: LMInput,
    parameters: GenerateParameters = GenerateParameters(),
    context: ModelContext,
    grammar: Grammar
) async throws -> AsyncThrowingStream<GrammarChunk, Error> {
    let sampler = parameters.sampler()
    let processor = try await GrammarMaskedLogitProcessor.from(
        configuration: context.configuration,
        grammar: grammar
    )
    let iterator = try TokenIterator(
        input: input,
        model: context.model,
        processor: processor,
        sampler: sampler
    )
    let upstream = generate(input: input, context: context, iterator: iterator)

    return AsyncThrowingStream { continuation in
        let task = Task {
            var totalTokens = 0
            for await generation in upstream {
                if Task.isCancelled { break }
                switch generation {
                case let .chunk(text):
                    // Approximate token count by chunk count — `Generation.chunk`
                    // is one decoded token's text per yield in MLXLMCommon's
                    // current pipeline. Exact counts come via `.info` at the
                    // tail; downstream consumers use this only for `progress`.
                    totalTokens += 1
                    continuation.yield(GrammarChunk(chunk: text, totalTokens: totalTokens))
                case let .info(info):
                    totalTokens = info.generationTokenCount
                case .toolCall:
                    continue
                }
            }
            continuation.finish()
        }
        continuation.onTermination = { _ in
            task.cancel()
        }
    }
}

public func generate<Content: Decodable>(
    input: LMInput,
    parameters: GenerateParameters = GenerateParameters(),
    context: ModelContext,
    schema: JSONSchema,
    generating _: Content.Type,
    indent: Int? = nil,
    didGenerate: ([Int]) -> GenerateDisposition = { _ in .more }
) async throws -> (GenerateResult, Content) {
    let grammar = try Grammar.schema(schema, indent: indent)
    let sampler = parameters.sampler()
    let processor = try await GrammarMaskedLogitProcessor.from(configuration: context.configuration, grammar: grammar)
    let iterator = try TokenIterator(input: input, model: context.model, processor: processor, sampler: sampler)
    let result = generate(input: input, context: context, iterator: iterator, didGenerate: didGenerate)
    let content = try JSONDecoder().decode(Content.self, from: Data(result.output.utf8))
    return (result, content)
}

#if compiler(>=6.2)
    @available(macOS 26.0, iOS 26.0, *)
    public func generate<Content: Generable>(
        input: LMInput,
        parameters: GenerateParameters = GenerateParameters(),
        context: ModelContext,
        generating _: Content.Type,
        indent: Int? = nil,
        didGenerate: ([Int]) -> GenerateDisposition = { _ in .more }
    ) async throws -> (GenerateResult, Content) {
        let sampler = parameters.sampler()
        let grammar = try Grammar.generable(Content.self, indent: indent)
        let processor = try await GrammarMaskedLogitProcessor.from(
            configuration: context.configuration,
            grammar: grammar
        )
        let iterator = try TokenIterator(input: input, model: context.model, processor: processor, sampler: sampler)
        let result = generate(input: input, context: context, iterator: iterator, didGenerate: didGenerate)
        let content = try Content(GeneratedContent(json: result.output))
        return (result, content)
    }

    @available(macOS 26.0, iOS 26.0, *)
    public func generate<Content: Generable>(
        input: LMInput,
        parameters: GenerateParameters = GenerateParameters(),
        context: ModelContext,
        generating _: Content.Type,
        indent: Int? = nil
    ) async throws -> AsyncStream<Content.PartiallyGenerated> {
        let sampler = parameters.sampler()
        let grammar = try Grammar.generable(Content.self, indent: indent)
        let processor = try await GrammarMaskedLogitProcessor.from(
            configuration: context.configuration,
            grammar: grammar
        )
        let iterator = try TokenIterator(input: input, model: context.model, processor: processor, sampler: sampler)
        let stream = generate(input: input, context: context, iterator: iterator)
        return AsyncStream { continuation in
            let task = Task {
                var output = ""
                for await generation in stream {
                    if let chunk = generation.chunk {
                        output.append(chunk)
                        let generatedContent = try GeneratedContent(json: output)
                        let partiallyGenerated = try Content.PartiallyGenerated(generatedContent)
                        continuation.yield(partiallyGenerated)
                    }
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
#endif
