@testable import Cast
import Foundation
import MLXLMCommon
import Testing

@Suite("ModelSource resolution")
struct ModelSourceTests {
    @Test("huggingFace with default revision resolves to .id with main")
    func huggingFaceDefaultRevision() throws {
        let source = ModelSource.huggingFace(id: "mlx-community/Llama-3.2-3B-Instruct-4bit")
        let (configuration, _) = try source.resolved()
        guard case let .id(id, revision) = configuration.id else {
            Issue.record("Expected .id identifier, got \(configuration.id)")
            return
        }
        #expect(id == "mlx-community/Llama-3.2-3B-Instruct-4bit")
        #expect(revision == "main")
    }

    @Test("huggingFace with explicit revision pins the revision")
    func huggingFaceExplicitRevision() throws {
        let source = ModelSource.huggingFace(id: "owner/repo", revision: "abc123")
        let (configuration, _) = try source.resolved()
        guard case let .id(id, revision) = configuration.id else {
            Issue.record("Expected .id identifier, got \(configuration.id)")
            return
        }
        #expect(id == "owner/repo")
        #expect(revision == "abc123")
    }

    @Test("directory resolves to .directory with the same URL")
    func directoryResolves() throws {
        let url = URL(fileURLWithPath: "/tmp/cast-models/llama")
        let source = ModelSource.directory(url)
        let (configuration, _) = try source.resolved()
        guard case let .directory(resolved) = configuration.id else {
            Issue.record("Expected .directory identifier, got \(configuration.id)")
            return
        }
        #expect(resolved == url)
    }

    @Test("bundle resolves to .directory pointing at the resource URL")
    func bundleResolves() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cast-bundle-\(UUID().uuidString)", isDirectory: true)
        let resourceDir = tmp.appendingPathComponent("model", isDirectory: true)
        try FileManager.default.createDirectory(at: resourceDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let bundle = try #require(Bundle(url: tmp))
        let source = ModelSource.bundle(bundle, resourceName: "model")
        let (configuration, _) = try source.resolved()
        guard case let .directory(resolved) = configuration.id else {
            Issue.record("Expected .directory identifier, got \(configuration.id)")
            return
        }
        #expect(resolved.standardizedFileURL == resourceDir.standardizedFileURL)
    }

    @Test("bundle with a missing resource throws .modelNotFound")
    func bundleMissingResource() {
        let source = ModelSource.bundle(.main, resourceName: "definitely-not-shipped-\(UUID().uuidString)")
        #expect(throws: CastError.self) {
            _ = try source.resolved()
        }
        do {
            _ = try source.resolved()
            Issue.record("Expected resolved() to throw")
        } catch let error as CastError {
            guard case .modelNotFound = error else {
                Issue.record("Expected .modelNotFound, got \(error)")
                return
            }
        } catch {
            Issue.record("Expected CastError, got \(error)")
        }
    }

    @Test("customEndpoint resolves with the given id and revision")
    func customEndpointResolves() throws {
        let endpoint = try #require(URL(string: "https://hf-mirror.corp.example.com"))
        let source = ModelSource.customEndpoint(
            id: "internal/llama-3.2-3b-4bit",
            endpoint: endpoint,
            revision: "v1.0"
        )
        let (configuration, _) = try source.resolved()
        guard case let .id(id, revision) = configuration.id else {
            Issue.record("Expected .id identifier, got \(configuration.id)")
            return
        }
        #expect(id == "internal/llama-3.2-3b-4bit")
        #expect(revision == "v1.0")
    }

    @Test("customEndpoint without explicit revision defaults to main")
    func customEndpointDefaultRevision() throws {
        let endpoint = try #require(URL(string: "https://example.com"))
        let source = ModelSource.customEndpoint(id: "x/y", endpoint: endpoint)
        let (configuration, _) = try source.resolved()
        guard case let .id(_, revision) = configuration.id else {
            Issue.record("Expected .id identifier, got \(configuration.id)")
            return
        }
        #expect(revision == "main")
    }
}
