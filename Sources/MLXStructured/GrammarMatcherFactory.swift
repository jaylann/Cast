import Hub
import MLXLMCommon

// Modifications: added public memberwise init for test instantiation by Justin Lanfermann, 2026.
public struct TokenizerArtifacts: Sendable {
    public let vocab: [String]
    public let vocabType: Int32
    public let stopTokenIds: [Int32]

    public init(vocab: [String], vocabType: Int32, stopTokenIds: [Int32]) {
        self.vocab = vocab
        self.vocabType = vocabType
        self.stopTokenIds = stopTokenIds
    }
}

public extension GrammarMaskedLogitProcessor {
    static func loadTokenizerArtifacts(
        hub: HubApi = .shared,
        configuration: ModelConfiguration
    ) async throws -> TokenizerArtifacts {
        let configurations = switch configuration.id {
        case let .id(id, revision):
            LanguageModelConfigurationFromHub(modelName: id, revision: revision, hubApi: hub)
        case let .directory(directory):
            LanguageModelConfigurationFromHub(modelFolder: directory, hubApi: hub)
        }

        let (modelConfig, tokenizerConfig, tokenizerData) = try await (
            configurations.modelConfig,
            configurations.tokenizerConfig,
            configurations.tokenizerData
        )

        let vocabSize = modelConfig?.vocabSize.integer()
            ?? modelConfig?.textConfig.vocabSize.integer()
            ?? 0
        var vocab = Array(repeating: "", count: vocabSize)

        for (key, value) in tokenizerData.model.vocab.dictionary(or: [:]) {
            if let index = value.integer() {
                if index >= vocab.count {
                    vocab.append(contentsOf: Array(repeating: "", count: index - vocab.count + 1))
                }
                vocab[index] = key.string
            }
        }

        for value in tokenizerData.addedTokens.array(or: []) {
            if let index = value.id.integer(), let token = value.content.string() {
                if index >= vocab.count {
                    vocab.append(contentsOf: Array(repeating: "", count: index - vocab.count + 1))
                }
                vocab[index] = token
            }
        }

        let decoders: [Config] = switch tokenizerData.decoder.type.string() {
        case "Sequence":
            tokenizerData.decoder.decoders.array(or: [])
        default:
            [tokenizerData.decoder]
        }

        var vocabType: Int32 = 0
        loop: for decoder in decoders {
            switch decoder.type.string() {
            case "ByteFallback":
                vocabType = 1
                break loop
            case "ByteLevel":
                vocabType = 2
                break loop
            default:
                continue
            }
        }

        var stopTokenIds: [Int32] = configuration.extraEOSTokens.compactMap(vocab.firstIndex).map(Int32.init)
        if let tokenizerConfig, let eosToken = tokenizerConfig.eosToken.string(),
           let eosTokenId = vocab.firstIndex(of: eosToken) {
            stopTokenIds.append(Int32(eosTokenId))
        }

        return TokenizerArtifacts(vocab: vocab, vocabType: vocabType, stopTokenIds: stopTokenIds)
    }

    static func from(
        artifacts: TokenizerArtifacts,
        grammar: Grammar
    ) throws -> GrammarMaskedLogitProcessor {
        let grammarMatcher = try XGrammar(
            vocab: artifacts.vocab,
            vocabType: artifacts.vocabType,
            stopTokenIds: artifacts.stopTokenIds,
            grammar: grammar
        )
        return GrammarMaskedLogitProcessor(grammarMatcher: grammarMatcher)
    }

    static func from(
        hub: HubApi = .shared,
        configuration: ModelConfiguration,
        grammar: Grammar
    ) async throws -> GrammarMaskedLogitProcessor {
        let artifacts = try await loadTokenizerArtifacts(hub: hub, configuration: configuration)
        return try from(artifacts: artifacts, grammar: grammar)
    }
}
