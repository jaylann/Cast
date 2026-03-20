import Foundation
import MLXLMCommon
import os

@preconcurrency import MLXLLM

public final class CastModel: Sendable {

    private let _container: OSAllocatedUnfairLock<ModelContainer?>

    public var container: ModelContainer? {
        _container.withLock { $0 }
    }

    public var isLoaded: Bool {
        container != nil
    }

    private init(container: ModelContainer) {
        _container = OSAllocatedUnfairLock(initialState: container)
    }

    /// Test-only initializer for creating a CastModel without loading a real model.
    init(_testContainer: ModelContainer? = nil) {
        _container = OSAllocatedUnfairLock(initialState: _testContainer)
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
        return CastModel(container: container)
    }

    public func unload() {
        _container.withLock { $0 = nil }
    }
}
