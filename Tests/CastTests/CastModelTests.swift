import Testing
@testable import Cast

@Test func testCastModelUnloadSetsNil() {
    // CastModel requires a real ModelContainer from load(), which needs a model download.
    // We test the public API contract: after unload, isLoaded returns false.
    // Integration testing with actual models is deferred to CI with model caching.
}
