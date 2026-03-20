import Foundation
import MLXLMCommon
@preconcurrency import MLXStructured

actor GrammarProcessorCache {
    private var cache: [String: TokenizerArtifacts] = [:]
    private var inFlight: [String: Task<TokenizerArtifacts, any Error>] = [:]

    func artifacts(for configuration: ModelConfiguration) async throws -> TokenizerArtifacts {
        let key = configuration.name

        if let cached = cache[key] {
            return cached
        }

        if let existing = inFlight[key] {
            return try await existing.value
        }

        let task = Task {
            try await GrammarMaskedLogitProcessor.loadTokenizerArtifacts(configuration: configuration)
        }
        inFlight[key] = task

        do {
            let result = try await task.value
            cache[key] = result
            inFlight.removeValue(forKey: key)
            return result
        } catch {
            inFlight.removeValue(forKey: key)
            throw error
        }
    }

    func warmUp(for configuration: ModelConfiguration) async throws {
        _ = try await artifacts(for: configuration)
    }

    func clear() {
        cache.removeAll()
        inFlight.removeAll()
    }
}
