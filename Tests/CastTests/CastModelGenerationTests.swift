import JSONSchema
import Testing
@testable import Cast

// MARK: - Test types for auto-schema generation

private struct SimpleReview: Codable, Sendable {
    var title: String
    var rating: Int
}

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
    } catch {
        Issue.record("Expected CastError, got \(type(of: error)): \(error)")
    }
}

@Test func testAutoSchemaCastThrowsModelNotLoaded() async throws {
    let model = CastModel()

    await #expect(throws: CastError.self) {
        let _: SimpleReview = try await model.cast("test")
    }
}

@Test func testCastJSONThrowsModelNotLoaded() async throws {
    let model = CastModel()

    await #expect(throws: CastError.self) {
        _ = try await model.castJSON("test", schema: SimpleReview.self)
    }
}

@Test func testCastJSONExplicitSchemaThrowsModelNotLoaded() async throws {
    let model = CastModel()
    let schema = JSONSchema.object(properties: ["x": .string()], required: ["x"])

    await #expect(throws: CastError.self) {
        _ = try await model.castJSON("test", schema: schema)
    }
}
