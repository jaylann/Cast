@testable import Cast
import Foundation
import Testing

#if canImport(UIKit) && os(iOS)
    import UIKit
#endif

// MARK: - abortInFlight is unconditional

@Test func abortInFlightWithNoWorkIsNoOp() {
    let model = CastModel()
    model.abortInFlight()
    model.abortInFlight()
}

@Test func abortInFlightCancelsRegisteredClosures() {
    let model = CastModel()
    let observed = NSLock()
    nonisolated(unsafe) var cancelled = 0

    // Register two synthetic in-flight closures directly into the registry.
    let id1 = UUID()
    let id2 = UUID()
    let bump: @Sendable () -> Void = {
        observed.lock(); cancelled += 1; observed.unlock()
    }
    model._inFlight.withLock { dict in
        dict[id1] = bump
        dict[id2] = bump
    }

    model.abortInFlight()

    observed.lock(); let final = cancelled; observed.unlock()
    #expect(final == 2)

    let remaining = model._inFlight.withLock { $0.count }
    #expect(remaining == 0)
}

// MARK: - enableBackgroundSafety is idempotent

@Test func enableDisableBackgroundSafetyIsIdempotent() {
    let model = CastModel()
    model.enableBackgroundSafety()
    model.enableBackgroundSafety()
    model.disableBackgroundSafety()
    model.disableBackgroundSafety()
}

// MARK: - iOS notification cancels in-flight

#if canImport(UIKit) && os(iOS)
    @Test func didEnterBackgroundCancelsInFlight() async {
        let model = CastModel()
        model.enableBackgroundSafety()
        defer { model.disableBackgroundSafety() }

        let lock = NSLock()
        nonisolated(unsafe) var cancelled = false
        let id = UUID()
        model._inFlight.withLock { dict in
            dict[id] = {
                lock.lock(); cancelled = true; lock.unlock()
            }
        }

        NotificationCenter.default.post(
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        // The observer runs synchronously on the main queue. Yield to let it land.
        try? await Task.sleep(for: .milliseconds(20))

        lock.lock(); let final = cancelled; lock.unlock()
        #expect(final == true)
    }

    /// Regression for #114: concurrent enableBackgroundSafety() must not leak
    /// orphan observers into NotificationCenter. After racing N enables and a
    /// single disable, posting didEnterBackground must not reach the model.
    @Test func enableBackgroundSafetyIsRaceSafe() async {
        let model = CastModel()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 64 {
                group.addTask { model.enableBackgroundSafety() }
            }
        }

        model.disableBackgroundSafety()

        let lock = NSLock()
        nonisolated(unsafe) var fired = false
        let id = UUID()
        model._inFlight.withLock { dict in
            dict[id] = {
                lock.lock(); fired = true; lock.unlock()
            }
        }

        NotificationCenter.default.post(
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        try? await Task.sleep(for: .milliseconds(50))

        lock.lock(); let final = fired; lock.unlock()
        #expect(final == false)
    }
#endif
