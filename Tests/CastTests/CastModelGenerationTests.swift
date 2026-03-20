import JSONSchema
import Testing
@testable import Cast

@Test func testCastThrowsModelNotLoaded() async throws {
    let model = CastModel()
    let schema = JSONSchema.object(properties: ["name": .string()], required: ["name"])

    await #expect(throws: CastError.self) {
        let _: [String: String] = try await model.cast("test", schema: schema)
    }
}

@Test func testCastThrowsModelNotLoadedWithCorrectCase() async throws {
    let model = CastModel()
    let schema = JSONSchema.object(properties: ["a": .string()], required: ["a"])

    do {
        let _: [String: String] = try await model.cast("test", schema: schema)
        Issue.record("Expected CastError.modelNotLoaded")
    } catch let error as CastError {
        guard case .modelNotLoaded = error else {
            Issue.record("Expected .modelNotLoaded, got \(error)")
            return
        }
    }
}
