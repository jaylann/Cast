@testable import Cast
import Foundation
import Testing

// MARK: - Already-balanced inputs pass through

@Test func repairBalancedObjectIsOk() {
    switch JSONRepair.repair("{\"a\":1}") {
    case let .ok(s):
        #expect(s == "{\"a\":1}")
    default:
        Issue.record("expected .ok")
    }
}

@Test func repairBalancedArrayIsOk() {
    switch JSONRepair.repair("[1,2,3]") {
    case let .ok(s):
        #expect(s == "[1,2,3]")
    default:
        Issue.record("expected .ok")
    }
}

@Test func repairBalancedWithWhitespaceIsOk() {
    switch JSONRepair.repair("  {\"a\":1}\n") {
    case .ok:
        return
    default:
        Issue.record("expected .ok for already-balanced input with whitespace")
    }
}

// MARK: - Unclosed string

@Test func repairUnclosedString() {
    switch JSONRepair.repair("{\"name\":\"Justi") {
    case let .repaired(value, _):
        #expect(value == "{\"name\":\"Justi\"}")
    default:
        Issue.record("expected .repaired")
    }
}

@Test func repairUnclosedStringWithEscapedQuote() {
    switch JSONRepair.repair("{\"q\":\"he said \\\"hi") {
    case let .repaired(value, _):
        // Escaped quote should not close the string prematurely.
        #expect(value == "{\"q\":\"he said \\\"hi\"}")
    default:
        Issue.record("expected .repaired")
    }
}

@Test func repairDanglingBackslash() {
    // Dangling backslash at EOF would escape our injected close-quote.
    switch JSONRepair.repair("{\"q\":\"foo\\") {
    case let .repaired(value, _):
        // Backslash dropped before close quote.
        #expect(value == "{\"q\":\"foo\"}")
    default:
        Issue.record("expected .repaired")
    }
}

@Test func repairPartialUnicodeEscape() {
    switch JSONRepair.repair("{\"q\":\"hi \\u00") {
    case let .repaired(value, _):
        // Partial \u escape dropped before string close.
        #expect(value == "{\"q\":\"hi \"}")
    default:
        Issue.record("expected .repaired")
    }
}

// MARK: - Unclosed containers

@Test func repairDeepUnclosedObject() {
    switch JSONRepair.repair("{\"a\":{\"b\":{\"c\":1") {
    case let .repaired(value, _):
        #expect(value == "{\"a\":{\"b\":{\"c\":1}}}")
    default:
        Issue.record("expected .repaired")
    }
}

@Test func repairUnclosedArrayInsideObject() {
    switch JSONRepair.repair("{\"items\":[1,2,3") {
    case let .repaired(value, _):
        #expect(value == "{\"items\":[1,2,3]}")
    default:
        Issue.record("expected .repaired")
    }
}

@Test func repairTrailingCommaInObject() {
    switch JSONRepair.repair("{\"a\":1,\"b\":2,") {
    case let .repaired(value, _):
        #expect(value == "{\"a\":1,\"b\":2}")
    default:
        Issue.record("expected .repaired")
    }
}

@Test func repairTrailingCommaInArray() {
    switch JSONRepair.repair("[1,2,3,") {
    case let .repaired(value, _):
        #expect(value == "[1,2,3]")
    default:
        Issue.record("expected .repaired")
    }
}

// MARK: - Dangling key/value fragments

@Test func repairDanglingKey() {
    switch JSONRepair.repair("{\"a\":1,\"b\"") {
    case let .repaired(value, _):
        #expect(value == "{\"a\":1}")
    default:
        Issue.record("expected .repaired")
    }
}

@Test func repairDanglingKeyWithColon() {
    switch JSONRepair.repair("{\"a\":1,\"b\":") {
    case let .repaired(value, _):
        #expect(value == "{\"a\":1}")
    default:
        Issue.record("expected .repaired")
    }
}

@Test func repairPartialTrueLiteral() {
    switch JSONRepair.repair("{\"flag\":tru") {
    case let .repaired(value, _):
        #expect(value == "{}")
    default:
        Issue.record("expected .repaired")
    }
}

@Test func repairPartialNullLiteral() {
    switch JSONRepair.repair("[1,2,nul") {
    case let .repaired(value, _):
        #expect(value == "[1,2]")
    default:
        Issue.record("expected .repaired")
    }
}

// MARK: - Unrecoverable

@Test func repairMismatchedClosersIsUnrecoverable() {
    switch JSONRepair.repair("{\"a\":1]") {
    case .unrecoverable:
        return
    default:
        Issue.record("expected .unrecoverable")
    }
}

@Test func repairUnopenedCloserIsUnrecoverable() {
    switch JSONRepair.repair("}") {
    case .unrecoverable:
        return
    default:
        Issue.record("expected .unrecoverable")
    }
}

// MARK: - Validation gate

@Test func repairResultIsValidJSON() {
    let cases = [
        "{\"name\":\"Justi",
        "{\"items\":[1,2,3",
        "{\"a\":1,\"b\":2,",
        "{\"a\":{\"b\":[",
        "[\"a\",\"b\"",
    ]
    for input in cases {
        let result = JSONRepair.repair(input)
        guard case let .repaired(value, _) = result else {
            Issue.record("repair did not succeed for: \(input)")
            continue
        }
        let valid = (try? JSONSerialization.jsonObject(with: Data(value.utf8))) != nil
        #expect(valid, "repaired output is not valid JSON: \(value)")
    }
}
