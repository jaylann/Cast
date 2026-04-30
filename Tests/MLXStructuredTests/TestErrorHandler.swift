//
//  TestErrorHandler.swift
//  MLXStructured
//
//  Created by Ivan Petrukha on 18.09.2025.
//

@testable import MLXStructured
import Testing

@Test(.requiresMetal) func emptyEBNFGrammar() {
    #expect(performing: {
        let grammar = Grammar.ebnf("")
        _ = try XGrammar(vocab: ["a", "b", "c"], grammar: grammar)
    }, throws: { error in
        switch error {
        case XGrammarError.emptyGrammar:
            true
        default:
            false
        }
    })
}

@Test(.requiresMetal) func incorrectEBNFGrammar() {
    #expect(performing: {
        let grammar = Grammar.ebnf("*")
        _ = try XGrammar(vocab: ["a", "b", "c"], grammar: grammar)
    }, throws: { error in
        switch error {
        case let XGrammarError.invalidGrammar(message):
            message.contains("The root rule with name \"root\" is not found")
        default:
            false
        }
    })
}

@Test(.requiresMetal) func emptyRegexGrammar() {
    #expect(performing: {
        let grammar = Grammar.regex("")
        _ = try XGrammar(vocab: ["a", "b", "c"], grammar: grammar)
    }, throws: { error in
        switch error {
        case XGrammarError.emptyGrammar:
            true
        default:
            false
        }
    })
}

@Test(.requiresMetal) func incorrectRegexGrammar() {
    #expect(performing: {
        let grammar = Grammar.regex("*")
        _ = try XGrammar(vocab: ["a", "b", "c"], grammar: grammar)
    }, throws: { error in
        switch error {
        case let XGrammarError.invalidGrammar(message):
            message.contains("Expect element, but got *")
        default:
            false
        }
    })
}

@Test(.requiresMetal) func emptyJSONSchemaGrammar() {
    #expect(performing: {
        let grammar = Grammar.schema("")
        _ = try XGrammar(vocab: ["a", "b", "c"], grammar: grammar)
    }, throws: { error in
        switch error {
        case XGrammarError.emptyGrammar:
            true
        default:
            false
        }
    })
}

@Test(.requiresMetal) func incorrectJSONSchemaGrammar() {
    #expect(performing: {
        let grammar = Grammar.schema(#"{"type": "foo"}"#)
        _ = try XGrammar(vocab: ["a", "b", "c"], grammar: grammar)
    }, throws: { error in
        switch error {
        case let XGrammarError.invalidGrammar(message):
            message.contains("Unsupported type \"foo\"")
        default:
            false
        }
    })
}
