@testable import Cast
import Foundation
import Testing

/// Local mirror of what the @Castable macro would synthesize for
/// `struct Movie { var title: String; var year: Int }`. Re-implementing here
/// avoids a runtime dependency on the macro from this test file (the macro
/// has its own expansion suite).
private struct Movie: Castable {
    var title: String = ""
    var year: Int = 0

    struct PartiallyGenerated: Sendable, Decodable {
        var title: String?
        var year: Int?
    }
}

/// Walk progressive byte fragments of a target JSON document through
/// `JSONRepair` + `Movie.PartiallyGenerated`, asserting each prefix either
/// produces a partial value or returns nil — never throws.
@Test func partialDecodeFromProgressiveFragments() {
    let fragments = [
        "{",
        "{\"ti",
        "{\"title\":\"Incept",
        "{\"title\":\"Inception\"",
        "{\"title\":\"Inception\",\"ye",
        "{\"title\":\"Inception\",\"year\":2010}"
    ]

    var decodedTitleAt: Int?
    var decodedYearAt: Int?

    for (idx, fragment) in fragments.enumerated() {
        let value = decodePartial(Movie.self, from: fragment)
        if let value, value.title != nil, decodedTitleAt == nil {
            decodedTitleAt = idx
        }
        if let value, value.year != nil, decodedYearAt == nil {
            decodedYearAt = idx
        }
    }

    #expect(decodedTitleAt != nil, "title should populate at some prefix")
    #expect(decodedYearAt != nil, "year should populate at some prefix")
    if let titleIdx = decodedTitleAt, let yearIdx = decodedYearAt {
        #expect(titleIdx <= yearIdx, "title appears before year in the source")
    }
}

@Test func emptyFragmentDoesNotCrash() {
    let value = decodePartial(Movie.self, from: "")
    #expect(value == nil)
}

@Test func unrecoverableFragmentReturnsNil() {
    // `}` with no opener is unrecoverable — must not throw.
    let value = decodePartial(Movie.self, from: "}")
    #expect(value == nil)
}

@Test func fullDocumentDecodesBothFields() {
    let value = decodePartial(
        Movie.self,
        from: "{\"title\":\"Inception\",\"year\":2010}"
    )
    #expect(value?.title == "Inception")
    #expect(value?.year == 2010)
}

// MARK: - Test helper that mirrors Cast/API/CastModel+Stream.swift's `decodePartial`

private func decodePartial<T: Castable>(_: T.Type, from buffer: String) -> T.PartiallyGenerated? {
    let candidate: String
    switch JSONRepair.repair(buffer) {
    case let .ok(value):
        candidate = value
    case let .repaired(value, _):
        candidate = value
    case .unrecoverable:
        return nil
    }
    return try? JSONDecoder().decode(T.PartiallyGenerated.self, from: Data(candidate.utf8))
}
