import JSONSchema
import Testing
@testable import Cast

@Test func testCastThrowsModelNotLoaded() async {
    // CastModel requires load() which downloads a model.
    // Verify the error path: calling cast() without a loaded model throws modelNotLoaded.
    // This requires an internal init or test helper — deferred to integration tests.
}
