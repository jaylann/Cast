import Testing
@testable import Cast

@Test func testErrorHandlerSetupDoesNotCrash() {
    CastModel.ensureErrorHandler()
    CastModel.ensureErrorHandler() // Idempotent — second call should be no-op
}

@Test func testCheckAndClearReturnsNilWhenNoError() {
    CastModel.ensureErrorHandler()
    let error = CastModel.checkAndClearMLXGlobalError()
    #expect(error == nil)
}
