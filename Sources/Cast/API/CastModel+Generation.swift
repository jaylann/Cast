import Foundation
import JSONSchema
import MLX
@preconcurrency import MLXLMCommon
@preconcurrency import MLXStructured

extension CastModel {

    /// Cast with auto-generated schema from a Decodable & Sendable type.
    public func cast<T: Decodable & Sendable>(
        _ prompt: String,
        as type: T.Type = T.self,
        system: String? = nil,
        config: CastConfiguration = CastConfiguration()
    ) async throws -> T {
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

        return try await cast(built.user, as: type, schema: schema, system: built.system, config: config)
    }

    /// Return raw JSON string with auto-generated schema.
    public func castJSON<T: Decodable & Sendable>(
        _ prompt: String,
        schema type: T.Type,
        system: String? = nil,
        config: CastConfiguration = CastConfiguration()
    ) async throws -> String {
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

        return try await castJSON(built.user, schema: schema, system: built.system, config: config)
    }

    /// Return raw JSON string with explicit schema.
    public func castJSON(
        _ prompt: String,
        schema: JSONSchema,
        system: String? = nil,
        config: CastConfiguration = CastConfiguration()
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

        let fullPrompt: String
        if let system {
            fullPrompt = "\(system)\n\n\(prompt)"
        } else {
            fullPrompt = prompt
        }

        let parameters = config.generateParameters

        let result: GenerateResult
        do {
            result = try await container.perform { context in
                let userInput = UserInput(prompt: fullPrompt)
                let lmInput = try await context.processor.prepare(input: userInput)

                return try await MLXStructured.generate(
                    input: lmInput,
                    parameters: parameters,
                    context: context,
                    grammar: grammar,
                    didGenerate: { _ in
                        Task.isCancelled ? .stop : .more
                    }
                )
            }
        } catch let error as CastError {
            cleanupGPU()
            throw error
        } catch {
            cleanupGPU()
            throw CastError.generationFailed(error.localizedDescription)
        }

        cleanupGPU()

        if let globalError = Self.checkAndClearMLXGlobalError() {
            throw CastError.generationFailed(globalError)
        }

        return result.output
    }

    /// Cast with explicit JSONSchema parameter.
    public func cast<T: Decodable>(
        _ prompt: String,
        as type: T.Type = T.self,
        schema: JSONSchema,
        system: String? = nil,
        config: CastConfiguration = CastConfiguration()
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

        let fullPrompt: String
        if let system {
            fullPrompt = "\(system)\n\n\(prompt)"
        } else {
            fullPrompt = prompt
        }

        let parameters = config.generateParameters

        let result: GenerateResult
        do {
            result = try await container.perform { context in
                let userInput = UserInput(prompt: fullPrompt)
                let lmInput = try await context.processor.prepare(input: userInput)

                return try await MLXStructured.generate(
                    input: lmInput,
                    parameters: parameters,
                    context: context,
                    grammar: grammar,
                    didGenerate: { _ in
                        Task.isCancelled ? .stop : .more
                    }
                )
            }
        } catch let error as CastError {
            cleanupGPU()
            throw error
        } catch {
            cleanupGPU()
            throw CastError.generationFailed(error.localizedDescription)
        }

        cleanupGPU()

        if let globalError = Self.checkAndClearMLXGlobalError() {
            throw CastError.generationFailed(globalError)
        }

        do {
            return try JSONDecoder().decode(T.self, from: Data(result.output.utf8))
        } catch {
            throw CastError.decodingFailed(
                rawOutput: result.output,
                error: error.localizedDescription
            )
        }
    }
}
