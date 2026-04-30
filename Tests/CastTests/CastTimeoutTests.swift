@testable import Cast
import Foundation
import Testing

// MARK: - withGenerationTimeout

@Test func timeoutNilReturnsResult() async throws {
    let result: Int = try await withGenerationTimeout(nil) {
        try await Task.sleep(for: .milliseconds(10))
        return 42
    }
    #expect(result == 42)
}

@Test func timeoutFastOperationReturnsResult() async throws {
    let result: String = try await withGenerationTimeout(.milliseconds(500)) {
        try await Task.sleep(for: .milliseconds(10))
        return "ok"
    }
    #expect(result == "ok")
}

@Test func timeoutSlowOperationThrowsTimedOut() async throws {
    do {
        let _: Int = try await withGenerationTimeout(.milliseconds(20)) {
            try await Task.sleep(for: .milliseconds(500))
            return 1
        }
        Issue.record("expected CastError.timedOut")
    } catch let error as CastError {
        guard case .timedOut = error else {
            Issue.record("expected .timedOut, got \(error)")
            return
        }
    } catch {
        Issue.record("expected CastError, got \(type(of: error)): \(error)")
    }
}

@Test func timeoutOperationCancelledOnDeadline() async throws {
    // The operation child should observe Task.isCancelled after the
    // deadline fires (group.cancelAll propagates).
    let observedCancellation = OSAllocatedUnfairLockBox(false)

    do {
        let _: Int = try await withGenerationTimeout(.milliseconds(20)) {
            for _ in 0 ..< 200 {
                if Task.isCancelled {
                    observedCancellation.set(true)
                    throw CancellationError()
                }
                do {
                    try await Task.sleep(for: .milliseconds(5))
                } catch is CancellationError {
                    observedCancellation.set(true)
                    throw CancellationError()
                }
            }
            return 0
        }
    } catch is CastError {
        // expected
    } catch {
        // ok
    }

    #expect(observedCancellation.get() == true)
}

// MARK: - CastError shape for new cases

@Test func timedOutErrorDescription() {
    let none = CastError.timedOut(partialOutput: nil).errorDescription ?? ""
    #expect(none.contains("timed out"))

    let some = CastError.timedOut(partialOutput: "{\"x\":").errorDescription ?? ""
    #expect(some.contains("timed out"))
    #expect(some.contains("{\"x\":"))
}

@Test func cancelledErrorDescription() {
    let none = CastError.cancelled(partialOutput: nil).errorDescription ?? ""
    #expect(none.contains("cancelled"))

    let some = CastError.cancelled(partialOutput: "{\"x\":").errorDescription ?? ""
    #expect(some.contains("cancelled"))
    #expect(some.contains("{\"x\":"))
}

@Test func repairFailedErrorDescription() {
    let error = CastError.repairFailed(rawOutput: "garbage", reason: "test reason")
    #expect(error.errorDescription?.contains("test reason") == true)
    #expect(error.errorDescription?.contains("garbage") == true)
}

// MARK: - CastConfiguration carries new fields

@Test func configurationDefaultsRepairAndTimeout() {
    let c = CastConfiguration()
    #expect(c.repairTruncatedJSON == true)
    #expect(c.timeout == nil)
}

@Test func configurationCustomTimeout() {
    let c = CastConfiguration(timeout: .seconds(5))
    #expect(c.timeout == .seconds(5))
}

@Test func configurationOptOutOfRepair() {
    let c = CastConfiguration(repairTruncatedJSON: false)
    #expect(c.repairTruncatedJSON == false)
}

// MARK: - Helper

private final class OSAllocatedUnfairLockBox<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value
    init(_ value: Value) {
        self.value = value
    }

    func set(_ newValue: Value) {
        lock.lock(); defer { lock.unlock() }
        value = newValue
    }

    func get() -> Value {
        lock.lock(); defer { lock.unlock() }
        return value
    }
}
