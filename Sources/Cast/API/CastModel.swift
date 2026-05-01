import Foundation
import MLXLMCommon
import os

@preconcurrency import MLXLLM

/// A loaded MLX language model, ready to produce structured output via
/// ``cast(_:as:system:config:didGenerate:)-2yyul`` and friends.
///
/// `CastModel` is `Sendable`. Construct one with ``load(_:progress:)`` (Cast
/// owns the model lifetime) or ``init(wrapping:configuration:)`` (you own
/// it). One model can be used concurrently from multiple Tasks; each
/// generation call is independently cancellable.
public final class CastModel: Sendable {
    private let _container: OSAllocatedUnfairLock<ModelContainer?>
    let _configuration: OSAllocatedUnfairLock<ModelConfiguration?>
    let grammarCache = GrammarProcessorCache()

    /// Registry of in-flight generation cancel closures, keyed by UUID.
    /// Populated by ``cast`` / ``castJSON`` for the duration of each call so
    /// ``abortInFlight()`` and the iOS background hook can cancel them.
    let _inFlight = OSAllocatedUnfairLock<[UUID: @Sendable () -> Void]>(initialState: [:])

    /// The wrapped MLX model container, or `nil` after ``unload()``.
    public var container: ModelContainer? {
        _container.withLock { $0 }
    }

    /// The MLX model configuration, or `nil` if the model isn't loaded.
    public var configuration: ModelConfiguration? {
        _configuration.withLock { $0 }
    }

    /// `true` while the model is loaded and ready to serve generation calls.
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

    /// Wrap an already-loaded `ModelContainer`. Use this when the caller
    /// manages model lifetime (sharing one container across components,
    /// loading from a custom path, etc.).
    public init(wrapping container: ModelContainer, configuration: ModelConfiguration) {
        _container = OSAllocatedUnfairLock(initialState: container)
        _configuration = OSAllocatedUnfairLock(initialState: configuration)
    }

    /// Download (if needed) and load an MLX model by its Hugging Face id.
    ///
    /// Convenience for the most common case. For local directories, app-bundled
    /// models, or custom HF mirror endpoints, use ``load(_:progress:)-(ModelSource,_)``
    /// with a ``ModelSource``.
    ///
    /// ```swift
    /// let model = try await CastModel.load("mlx-community/Llama-3.2-3B-Instruct-4bit")
    /// ```
    ///
    /// - Parameters:
    ///   - modelId: A Hugging Face `org/repo` identifier (typically under
    ///     `mlx-community/`).
    ///   - progress: Optional download/load progress callback.
    public static func load(
        _ modelId: String,
        progress: (@Sendable (Progress) -> Void)? = nil
    ) async throws -> CastModel {
        try await load(.huggingFace(id: modelId), progress: progress)
    }

    /// Download (if needed) and load an MLX model from any ``ModelSource`` —
    /// Hugging Face Hub, a local directory, an app-bundled resource, or a
    /// custom HF-shaped endpoint.
    ///
    /// ```swift
    /// // Local pre-downloaded model
    /// let model = try await CastModel.load(
    ///     .directory(URL(fileURLWithPath: "/Users/me/Models/llama-3.2-3b-4bit"))
    /// )
    ///
    /// // Corporate HF mirror
    /// guard let endpoint = URL(string: "https://hf-mirror.corp.example.com") else {
    ///     throw URLError(.badURL)
    /// }
    /// let model = try await CastModel.load(
    ///     .customEndpoint(
    ///         id: "internal/llama-3.2-3b-4bit",
    ///         endpoint: endpoint,
    ///         revision: "v1.0"
    ///     )
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - source: Where to find the model.
    ///   - progress: Optional download/load progress callback. **No-op** for
    ///     `.directory` and `.bundle` sources — they have nothing to download,
    ///     so the callback never fires. Only meaningful for `.huggingFace` and
    ///     `.customEndpoint`.
    public static func load(
        _ source: ModelSource,
        progress: (@Sendable (Progress) -> Void)? = nil
    ) async throws -> CastModel {
        let (configuration, hub) = try source.resolved()
        let container = try await LLMModelFactory.shared.loadContainer(
            hub: hub,
            configuration: configuration
        ) { prog in
            progress?(prog)
        }
        return CastModel(container: container, configuration: configuration)
    }

    /// Release the underlying container. Subsequent generation calls throw
    /// ``CastError/modelNotLoaded``.
    public func unload() {
        _container.withLock { $0 = nil }
    }

    /// Pay the one-time grammar-compilation cost for each `(model, type)`
    /// pair up front. After warm-up, the first real `cast()` call is
    /// noticeably faster.
    ///
    /// ```swift
    /// try await model.prepare(Recipe.self, Sentiment.self)
    /// ```
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
