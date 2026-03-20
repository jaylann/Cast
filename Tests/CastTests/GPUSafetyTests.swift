import Testing
@testable import Cast

@Test func testErrorHandlerSetupIsIdempotent() {
    CastModel.ensureErrorHandler()
    CastModel.ensureErrorHandler()
}

@Test func testCheckAndClearReturnsNilWhenNoError() {
    CastModel.ensureErrorHandler()
    let error = CastModel.checkAndClearMLXGlobalError()
    #expect(error == nil)
}

@Test func testCheckAndClearIsAtomic() {
    CastModel.ensureErrorHandler()
    // First read clears any stale state
    _ = CastModel.checkAndClearMLXGlobalError()
    // Second read should also be nil
    let error = CastModel.checkAndClearMLXGlobalError()
    #expect(error == nil)
}

@Test func testCleanupGPUDoesNotCrash() {
    let model = CastModel()
    // cleanupGPU on an unloaded model should not crash (try? swallows errors)
    model.cleanupGPU()
}
