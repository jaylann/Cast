@testable import Cast
import Testing

@Suite("CastError")
struct CastErrorTests {
    @Test("modelNotLoaded surfaces a 'not loaded' description")
    func modelNotLoadedDescription() {
        let error = CastError.modelNotLoaded
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription?.contains("not loaded") == true)
    }

    @Test("schemaGenerationFailed includes the supplied detail")
    func schemaGenerationFailedDescription() {
        let error = CastError.schemaGenerationFailed("invalid type")
        #expect(error.errorDescription?.contains("invalid type") == true)
    }

    @Test("decodingFailed includes both the raw output and decoder error")
    func decodingFailedDescription() {
        let error = CastError.decodingFailed(rawOutput: "{bad json", error: "missing key")
        #expect(error.errorDescription?.contains("missing key") == true)
        #expect(error.errorDescription?.contains("{bad json") == true)
    }

    @Test("generationFailed includes the supplied detail")
    func generationFailedDescription() {
        let error = CastError.generationFailed("timeout")
        #expect(error.errorDescription?.contains("timeout") == true)
    }

    @Test("unsupportedType includes the offending type name")
    func unsupportedTypeDescription() {
        let error = CastError.unsupportedType("UIView")
        #expect(error.errorDescription?.contains("UIView") == true)
    }

    @Test("modelNotFound includes the supplied detail")
    func modelNotFoundDescription() {
        let error = CastError.modelNotFound("Bundle resource 'foo' not found")
        #expect(error.errorDescription?.contains("Bundle resource 'foo' not found") == true)
    }
}
