@testable import Cast
import Testing

@Test func errorHandlerSetupIsIdempotent() {
    CastModel.ensureErrorHandler()
    CastModel.ensureErrorHandler()
}

@Test func checkAndClearReturnsNilWhenNoError() {
    CastModel.ensureErrorHandler()
    let error = CastModel.checkAndClearMLXGlobalError()
    #expect(error == nil)
}

@Test func checkAndClearIsAtomic() {
    CastModel.ensureErrorHandler()
    // First read clears any stale state
    _ = CastModel.checkAndClearMLXGlobalError()
    // Second read should also be nil
    let error = CastModel.checkAndClearMLXGlobalError()
    #expect(error == nil)
}

@Test(.requiresMetal) func cleanupGPUDoesNotCrash() {
    let model = CastModel()
    // cleanupGPU on an unloaded model should not crash (try? swallows errors)
    model.cleanupGPU()
}
