import Testing
@testable import Cast

@Test func testModelNotLoadedError() {
    let error = CastError.modelNotLoaded
    #expect(error.errorDescription != nil)
    #expect(error.errorDescription?.contains("not loaded") == true)
}

@Test func testSchemaGenerationFailedError() {
    let error = CastError.schemaGenerationFailed("invalid type")
    #expect(error.errorDescription?.contains("invalid type") == true)
}

@Test func testDecodingFailedError() {
    let error = CastError.decodingFailed(rawOutput: "{bad json", error: "missing key")
    #expect(error.errorDescription?.contains("missing key") == true)
    #expect(error.errorDescription?.contains("{bad json") == true)
}

@Test func testGenerationFailedError() {
    let error = CastError.generationFailed("timeout")
    #expect(error.errorDescription?.contains("timeout") == true)
}

@Test func testUnsupportedTypeError() {
    let error = CastError.unsupportedType("UIView")
    #expect(error.errorDescription?.contains("UIView") == true)
}
