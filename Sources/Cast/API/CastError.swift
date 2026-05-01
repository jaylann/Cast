import Foundation

/// Errors thrown by the Cast generation pipeline.
public enum CastError: LocalizedError, Sendable {
    /// `CastModel.load(...)` was not called or the model was unloaded.
    case modelNotLoaded
    /// Schema generation from the requested type failed.
    case schemaGenerationFailed(String)
    /// The (possibly repaired) JSON failed to decode into the requested type.
    case decodingFailed(rawOutput: String, error: String)
    /// MLX generation itself failed (out-of-memory, sampler error, etc.).
    case generationFailed(String)
    /// The requested type cannot be projected into a JSON schema.
    case unsupportedType(String)
    /// Truncated output could not be repaired into valid JSON.
    /// `rawOutput` is the original (un-repaired) tail.
    case repairFailed(rawOutput: String, reason: String)
    /// `CastConfiguration.timeout` expired before generation completed.
    /// `partialOutput` is the bytes the model had produced (when available).
    case timedOut(partialOutput: String?)
    /// The wrapping `Task` was cancelled (user cancel, background transition,
    /// or `abortInFlight()`). `partialOutput` is the bytes generated up to
    /// the cancel point.
    case cancelled(partialOutput: String?)
    /// The requested model could not be located on disk. Currently thrown
    /// for `.bundle` sources whose `resourceName` doesn't resolve in the
    /// given `Bundle`. May also surface for invalid `.directory` URLs once
    /// upfront-existence validation is added.
    case modelNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            "Model is not loaded. Call CastModel.load() first."
        case let .schemaGenerationFailed(detail):
            "Schema generation failed: \(detail)"
        case let .decodingFailed(rawOutput, error):
            "Failed to decode model output: \(error). Raw output: \(String(rawOutput.prefix(200)))"
        case let .generationFailed(detail):
            "Generation failed: \(detail)"
        case let .unsupportedType(type):
            "Unsupported type: \(type)"
        case let .repairFailed(rawOutput, reason):
            "Could not repair truncated JSON (\(reason)). Raw output: \(String(rawOutput.prefix(200)))"
        case let .timedOut(partial):
            if let partial {
                "Generation timed out. Partial output: \(String(partial.prefix(200)))"
            } else {
                "Generation timed out before any output was produced."
            }
        case let .cancelled(partial):
            if let partial {
                "Generation cancelled. Partial output: \(String(partial.prefix(200)))"
            } else {
                "Generation cancelled before any output was produced."
            }
        case let .modelNotFound(detail):
            "Model not found: \(detail)"
        }
    }
}
