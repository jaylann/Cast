import Foundation
import MLXLMCommon
import os

@preconcurrency import MLXLLM

public final class CastModel: Sendable {

    private let _container: OSAllocatedUnfairLock<ModelContainer?>
    let _configuration: OSAllocatedUnfairLock<ModelConfiguration?>
    let grammarCache = GrammarProcessorCache()

    public var container: ModelContainer? {
        _container.withLock { $0 }
    }

    public var configuration: ModelConfiguration? {
        _configuration.withLock { $0 }
    }

    public var isLoaded: Bool {
        container != nil
    }

    private init(container: ModelContainer, configuration: ModelConfiguration) {
        _container = OSAllocatedUnfairLock(initialState: container)
        _configuration = OSAllocatedUnfairLock(initialState: configuration)
    }

    /// Test-only initializer for creating a CastModel without loading a real model.
    init(_testContainer: ModelContainer? = nil) {
        _container = OSAllocatedUnfairLock(initialState: _testContainer)
        _configuration = OSAllocatedUnfairLock(initialState: nil)
    }

    public static func load(
        _ modelId: String,
        progress: (@Sendable (Progress) -> Void)? = nil
    ) async throws -> CastModel {
        let configuration = ModelConfiguration(id: modelId)
        let container = try await LLMModelFactory.shared.loadContainer(
            configuration: configuration
        ) { prog in
            progress?(prog)
        }
        return CastModel(container: container, configuration: configuration)
    }

    public func unload() {
        _container.withLock { $0 = nil }
    }

    public func prepare(_ types: (any (Decodable & Sendable).Type)...) async throws {
        guard let configuration else {
            throw CastError.modelNotLoaded
        }

        for type in types {
            _ = try SchemaGenerator.schema(for: type)
        }

        try await grammarCache.warmUp(for: configuration)
    }
}
