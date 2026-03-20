import MLXLMCommon

public struct CastConfiguration: Sendable {

    public var maxTokens: Int
    public var temperature: Float
    public var topP: Float

    public init(
        maxTokens: Int = 1024,
        temperature: Float = 0.7,
        topP: Float = 0.9
    ) {
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
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
