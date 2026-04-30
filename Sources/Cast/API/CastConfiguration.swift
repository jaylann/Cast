import MLXLMCommon

/// Knobs for a single ``CastModel`` generation call.
///
/// Defaults are tuned for typed structured output (`cast()` / `classify()`).
/// Construct a fresh value per call when you need to override one knob:
/// ```swift
/// var config = CastConfiguration()
/// config.maxTokens = 512
/// config.temperature = 0.0
/// let r: Recipe = try await model.cast("...", config: config)
/// ```
public struct CastConfiguration: Sendable {
    /// Hard cap on tokens generated for this call.
    public var maxTokens: Int
    /// Sampling temperature. `0.0` is greedy/deterministic.
    public var temperature: Float
    /// Nucleus sampling threshold (`top-p`).
    public var topP: Float
    /// When `true`, attempt to repair a truncated JSON tail before decoding.
    /// Defaults to `true`. Set `false` to opt out and surface raw decoder
    /// errors instead. See ``JSONRepair``.
    public var repairTruncatedJSON: Bool
    /// Optional wall-clock timeout for the whole call. `nil` (default) waits
    /// indefinitely. On expiry, the call throws ``CastError/timedOut(partialOutput:)``.
    public var timeout: Duration?

    public init(
        maxTokens: Int = 1024,
        temperature: Float = 0.7,
        topP: Float = 0.9,
        repairTruncatedJSON: Bool = true,
        timeout: Duration? = nil
    ) {
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.repairTruncatedJSON = repairTruncatedJSON
        self.timeout = timeout
    }
}

extension CastConfiguration {
    var generateParameters: GenerateParameters {
        GenerateParameters(
            maxTokens: maxTokens,
            temperature: temperature,
            topP: topP
        )
    }
}
