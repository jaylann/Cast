@testable import Cast
import Collections
import Foundation
import JSONSchema
import Testing

@Castable
private struct StreamMovie {
    var title: String = ""
    var year: Int = 0
}

@Test("castStream yields monotonic progress and a terminal full value", .requiresMetal)
func castStreamProducesPartialsAndTerminal() async throws {
    let model = try await CastModel.load("mlx-community/Llama-3.2-3B-Instruct-4bit")
    let prompt = "Inception is a 2010 sci-fi film."

    var snapshots: [PartialResult<StreamMovie>] = []
    for try await partial in model.castStream(prompt, as: StreamMovie.self) {
        snapshots.append(partial)
    }

    #expect(snapshots.count >= 2, "expected at least one partial yield before the terminal one")

    let progress = snapshots.map(\.progress)
    for window in zip(progress, progress.dropFirst()) {
        #expect(window.0 <= window.1, "progress must be non-decreasing")
    }

    let final = try #require(snapshots.last)
    #expect(final.value.title != nil)
    #expect(final.value.year != nil)

    let direct: StreamMovie = try await model.cast(prompt, as: StreamMovie.self)
    #expect(final.value.title == direct.title)
    #expect(final.value.year == direct.year)
}
