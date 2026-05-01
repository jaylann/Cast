import Foundation
import Hub
import MLXLMCommon

/// Where a model's weights and tokenizer live. Use with
/// ``CastModel/load(_:progress:)-(ModelSource,_)``.
///
/// - `huggingFace`: Hugging Face Hub at the default endpoint.
/// - `directory`: a pre-downloaded model directory on disk.
/// - `bundle`: a model directory shipped inside an app's resource folder.
/// - `customEndpoint`: an HF-shaped repo served from a custom URL
///   (mirror, corporate CDN, proxy).
public enum ModelSource: Sendable {
    /// A model on Hugging Face Hub at the default endpoint, identified by
    /// `org/repo`. `revision` defaults to `"main"`.
    case huggingFace(id: String, revision: String? = nil)
    /// A model directory already present on disk at the given URL.
    case directory(URL)
    /// A model directory shipped as a resource in `bundle` under
    /// `resourceName`.
    case bundle(_ bundle: Bundle = .main, resourceName: String)
    /// A Hugging Face-shaped repo served from a custom URL — mirror,
    /// corporate CDN, or local proxy. `downloadBase` overrides where files
    /// are written; `revision` defaults to `"main"`.
    case customEndpoint(
        id: String,
        endpoint: URL,
        downloadBase: URL? = nil,
        revision: String? = nil
    )
}

extension ModelSource {
    /// Resolve to the underlying `ModelConfiguration` + `HubApi` pair that
    /// `LLMModelFactory.shared.loadContainer` expects. `.huggingFace`,
    /// `.directory`, and `.bundle` reuse `HubApi.shared`; `.customEndpoint`
    /// constructs a fresh `HubApi` carrying the supplied endpoint and
    /// optional `downloadBase`.
    func resolved() throws -> (configuration: ModelConfiguration, hub: HubApi) {
        switch self {
        case let .huggingFace(id, revision):
            let revision = revision ?? "main"
            return (ModelConfiguration(id: id, revision: revision), .shared)

        case let .directory(url):
            return (ModelConfiguration(directory: url), .shared)

        case let .bundle(bundle, resourceName):
            // `withExtension: ""` is Apple's documented sentinel for "no
            // extension" — passing `nil` would otherwise return the first
            // file matching the base name regardless of extension.
            guard let url = bundle.url(forResource: resourceName, withExtension: "") else {
                throw CastError.modelNotFound(
                    "Bundle resource '\(resourceName)' not found in \(bundle.bundleIdentifier ?? "<unknown bundle>")"
                )
            }
            return (ModelConfiguration(directory: url), .shared)

        case let .customEndpoint(id, endpoint, downloadBase, revision):
            let revision = revision ?? "main"
            let hub = HubApi(downloadBase: downloadBase, endpoint: endpoint.absoluteString)
            return (ModelConfiguration(id: id, revision: revision), hub)
        }
    }
}
