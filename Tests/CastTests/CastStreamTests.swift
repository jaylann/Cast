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

@Suite("castStream non-Metal seam")
struct CastStreamSeamTests {
    @Test("decodePartial returns nil for unrepairable buffer")
    func decodePartialReturnsNilForUnrepairableBuffer() {
        // "not even close" is a non-JSON string with no opening brace —
        // JSONRepair.repair returns .unrecoverable, so StreamDecode.partial yields nil.
        let snapshot = StreamDecode.partial(
            StreamMovie.self,
            from: "not even close",
            tokenCount: 1,
            maxTokens: 100,
            minProgress: 0
        )
        #expect(snapshot == nil)
    }

    @Test("decodePartial decodes valid partial JSON")
    func decodePartialDecodesValidPartialJSON() throws {
        let snapshot = StreamDecode.partial(
            StreamMovie.self,
            from: "{\"title\": \"Inception\"",
            tokenCount: 5,
            maxTokens: 100,
            minProgress: 0
        )
        let value = try #require(snapshot)
        #expect(value.value.title == "Inception")
        #expect(value.value.year == nil)
    }

    @Test("decodePartial reports monotonic progress across calls")
    func decodePartialMonotonicProgress() throws {
        let buffer = "{\"title\": \"Inception\""
        var minProgress = 0.0
        var observed: [Double] = []

        for tokens in [10, 30, 30, 40] {
            let snapshot = StreamDecode.partial(
                StreamMovie.self,
                from: buffer,
                tokenCount: tokens,
                maxTokens: 100,
                minProgress: minProgress
            )
            let value = try #require(snapshot)
            observed.append(value.progress)
            minProgress = value.progress
        }

        for window in zip(observed, observed.dropFirst()) {
            #expect(window.0 <= window.1)
        }
    }

    @Test("decodePartial clamps progress at 1.0")
    func decodePartialProgressClampedToOne() throws {
        let snapshot = StreamDecode.partial(
            StreamMovie.self,
            from: "{\"title\": \"Inception\"",
            tokenCount: 200,
            maxTokens: 100,
            minProgress: 0
        )
        let value = try #require(snapshot)
        #expect(value.progress == 1.0)
    }

    @Test("StreamBufferHolder snapshot is nil when empty")
    func streamBufferHolderEmptyReturnsNil() {
        let holder = StreamDecode.BufferHolder()
        #expect(holder.snapshot() == nil)
    }

    @Test("StreamBufferHolder round-trips set + snapshot")
    func streamBufferHolderRoundTrips() {
        let holder = StreamDecode.BufferHolder()
        holder.set("hello")
        #expect(holder.snapshot() == "hello")
    }

    @Test("StreamBufferHolder concurrent sets converge without crash")
    func streamBufferHolderConcurrentSetsConverge() async {
        let holder = StreamDecode.BufferHolder()
        let candidates = (0 ..< 10).map { "value-\($0)" }

        await withTaskGroup(of: Void.self) { group in
            for candidate in candidates {
                group.addTask {
                    holder.set(candidate)
                }
            }
        }

        let final = holder.snapshot()
        #expect(final != nil)
        #expect(candidates.contains(final ?? ""))
    }

    @Test("yieldTerminal repairs and yields one PartialResult")
    func yieldTerminalRepairsAndYields() async throws {
        var streamContinuation: AsyncThrowingStream<PartialResult<StreamMovie>, Error>.Continuation!
        let stream = AsyncThrowingStream<PartialResult<StreamMovie>, Error> { continuation in
            streamContinuation = continuation
        }

        var config = CastConfiguration()
        config.repairTruncatedJSON = true

        try StreamDecode.terminal(
            StreamMovie.self,
            buffer: "{\"title\": \"Inception\", \"year\": 2010",
            tokenCount: 50,
            maxTokens: 100,
            minProgress: 0,
            config: config,
            continuation: streamContinuation
        )
        streamContinuation.finish()

        var collected: [PartialResult<StreamMovie>] = []
        for try await partial in stream {
            collected.append(partial)
        }
        #expect(collected.count == 1)
        let only = try #require(collected.first)
        #expect(only.value.title == "Inception")
        #expect(only.value.year == 2010)
    }

    @Test("yieldTerminal throws decodingFailed when repair is off")
    func yieldTerminalThrowsOnRepairFailure() {
        var streamContinuation: AsyncThrowingStream<PartialResult<StreamMovie>, Error>.Continuation!
        let _stream = AsyncThrowingStream<PartialResult<StreamMovie>, Error> { continuation in
            streamContinuation = continuation
        }

        var config = CastConfiguration()
        config.repairTruncatedJSON = false

        #expect {
            try StreamDecode.terminal(
                StreamMovie.self,
                buffer: "{\"title\": \"Inception\", \"year\": 2010",
                tokenCount: 50,
                maxTokens: 100,
                minProgress: 0,
                config: config,
                continuation: streamContinuation
            )
        } throws: { error in
            guard let castError = error as? CastError,
                  case .decodingFailed = castError
            else {
                return false
            }
            return true
        }
    }

    @Test("yieldTerminal throws repairFailed on unrecoverable buffer")
    func yieldTerminalThrowsRepairFailedOnUnrecoverable() {
        var streamContinuation: AsyncThrowingStream<PartialResult<StreamMovie>, Error>.Continuation!
        let _stream = AsyncThrowingStream<PartialResult<StreamMovie>, Error> { continuation in
            streamContinuation = continuation
        }

        var config = CastConfiguration()
        config.repairTruncatedJSON = true

        #expect {
            try StreamDecode.terminal(
                StreamMovie.self,
                buffer: "not even close",
                tokenCount: 50,
                maxTokens: 100,
                minProgress: 0,
                config: config,
                continuation: streamContinuation
            )
        } throws: { error in
            guard let castError = error as? CastError,
                  case .repairFailed = castError
            else {
                return false
            }
            return true
        }
    }
}
