import Foundation

public enum CastError: LocalizedError, Sendable {

    case modelNotLoaded
    case schemaGenerationFailed(String)
    case decodingFailed(rawOutput: String, error: String)
    case generationFailed(String)
    case unsupportedType(String)

    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            "Model is not loaded. Call CastModel.load() first."
        case .schemaGenerationFailed(let detail):
            "Schema generation failed: \(detail)"
        case .decodingFailed(let rawOutput, let error):
            "Failed to decode model output: \(error). Raw output: \(String(rawOutput.prefix(200)))"
        case .generationFailed(let detail):
            "Generation failed: \(detail)"
        case .unsupportedType(let type):
            "Unsupported type: \(type)"
        }
    }
}
