@testable import Cast
import Testing

@Test func modelNotLoadedError() {
    let error = CastError.modelNotLoaded
    #expect(error.errorDescription != nil)
    #expect(error.errorDescription?.contains("not loaded") == true)
}

@Test func schemaGenerationFailedError() {
    let error = CastError.schemaGenerationFailed("invalid type")
    #expect(error.errorDescription?.contains("invalid type") == true)
}

@Test func decodingFailedError() {
    let error = CastError.decodingFailed(rawOutput: "{bad json", error: "missing key")
    #expect(error.errorDescription?.contains("missing key") == true)
    #expect(error.errorDescription?.contains("{bad json") == true)
}

@Test func generationFailedError() {
    let error = CastError.generationFailed("timeout")
    #expect(error.errorDescription?.contains("timeout") == true)
}

@Test func unsupportedTypeError() {
    let error = CastError.unsupportedType("UIView")
    #expect(error.errorDescription?.contains("UIView") == true)
}

@Test func modelNotFoundError() {
    let error = CastError.modelNotFound("Bundle resource 'foo' not found")
    #expect(error.errorDescription?.contains("Bundle resource 'foo' not found") == true)
}
