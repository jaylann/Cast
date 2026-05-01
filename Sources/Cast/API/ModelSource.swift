import Foundation
import Hub
import MLXLMCommon

/// Where a model's weights and tokenizer live. Use with
/// ``CastModel/load(_:progress:)-(_,_)``.
///
/// - `huggingFace`: Hugging Face Hub at the default endpoint.
/// - `directory`: a pre-downloaded model directory on disk.
/// - `bundle`: a model directory shipped inside an app's resource folder.
/// - `customEndpoint`: an HF-shaped repo served from a custom URL
///   (mirror, corporate CDN, proxy).
public enum ModelSource: Sendable {
    case huggingFace(id: String, revision: String? = nil)
    case directory(URL)
    case bundle(_ bundle: Bundle = .main, resourceName: String)
    case customEndpoint(
        id: String,
        endpoint: URL,
        downloadBase: URL? = nil,
        revision: String? = nil
    )
}

extension ModelSource {
    /// Resolve to the underlying `ModelConfiguration` + `HubApi` pair that
    /// `LLMModelFactory.shared.loadContainer` expects.
    func resolved() throws -> (configuration: ModelConfiguration, hub: HubApi) {
        switch self {
        case let .huggingFace(id, revision):
            let revision = revision ?? "main"
            return (ModelConfiguration(id: id, revision: revision), .shared)

        case let .directory(url):
            return (ModelConfiguration(directory: url), .shared)

        case let .bundle(bundle, resourceName):
            guard let url = bundle.url(forResource: resourceName, withExtension: nil) else {
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
