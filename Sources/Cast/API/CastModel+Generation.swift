import Foundation
import JSONSchema
import MLX
@preconcurrency import MLXLMCommon
@preconcurrency import MLXStructured

extension CastModel {

    public func cast<T: Decodable>(
        _ prompt: String,
        as type: T.Type = T.self,
        schema: JSONSchema,
        system: String? = nil,
        config: CastConfiguration = CastConfiguration()
    ) async throws -> T {
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

        let result = try await container.perform { context in
            let userInput = UserInput(prompt: fullPrompt)
            let lmInput = try await context.processor.prepare(input: userInput)

            return try await MLXStructured.generate(
                input: lmInput,
                parameters: parameters,
                context: context,
                grammar: grammar
            )
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
