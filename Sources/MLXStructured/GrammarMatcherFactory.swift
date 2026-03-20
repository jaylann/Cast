//
//  GrammarMatcherFactory.swift
//  MLXStructured
//
//  Created by Ivan Petrukha on 20.09.2025.
//

import Hub
import MLXLMCommon

public extension GrammarMaskedLogitProcessor {
    static func from(
        hub: HubApi = .shared, // TODO: Request changes in swift-transformers to make the tokenizer vocab (and some other properties) public
        configuration: ModelConfiguration,
        grammar: Grammar
    ) async throws -> GrammarMaskedLogitProcessor {
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

        // VLMs (e.g. Qwen3.5) nest vocab_size inside text_config
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
        if let tokenizerConfig, let eosToken = tokenizerConfig.eosToken.string(), let eosTokenId = vocab.firstIndex(of: eosToken) {
            stopTokenIds.append(Int32(eosTokenId))
        }

//        print("Vocab size:", vocab.count)
//        print("Vocab type:", vocabType)
//        print("Stop tokens Ids:", stopTokenIds)
//        print("Grammar:", grammar)

        let grammarMatcher = try XGrammar(vocab: vocab, vocabType: vocabType, stopTokenIds: stopTokenIds, grammar: grammar)
        return GrammarMaskedLogitProcessor(grammarMatcher: grammarMatcher)
    }
}
