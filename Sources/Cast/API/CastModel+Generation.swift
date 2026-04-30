import Foundation
import JSONSchema
import MLX
@preconcurrency import MLXLMCommon
@preconcurrency import MLXStructured

public extension CastModel {
    /// Cast with auto-generated schema from a Decodable & Sendable type.
    func cast<T: Decodable & Sendable>(
        _ prompt: String,
        as type: T.Type = T.self,
        system: String? = nil,
        config: CastConfiguration = CastConfiguration(),
        didGenerate: (@Sendable (Int) -> GenerateDisposition)? = nil
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

        return try await cast(
            built.user,
            as: type,
            schema: schema,
            system: built.system,
            config: config,
            didGenerate: didGenerate
        )
    }

    /// Return raw JSON string with auto-generated schema.
    func castJSON(
        _ prompt: String,
        schema type: (some Decodable & Sendable).Type,
        system: String? = nil,
        config: CastConfiguration = CastConfiguration(),
        didGenerate: (@Sendable (Int) -> GenerateDisposition)? = nil
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

        return try await castJSON(
            built.user,
            schema: schema,
            system: built.system,
            config: config,
            didGenerate: didGenerate
        )
    }

    /// Return raw JSON string with explicit schema.
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
            result = try await container.perform { context in
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
            result = try await container.perform { context in
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
            return try ValidatorSupport.decode(T.self, from: Data(result.output.utf8))
        } catch {
            throw CastError.decodingFailed(
                rawOutput: result.output,
                error: error.localizedDescription
            )
        }
    }

    /// Classify input into a CastEnum value (String raw value).
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

    /// Classify input into a CastEnum value (Int raw value).
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
