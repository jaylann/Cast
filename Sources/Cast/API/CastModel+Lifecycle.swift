// File rationale: in-flight cancellation and iOS app-lifecycle plumbing.
// Owns: `abortInFlight()`, `enableBackgroundSafety()`/`disableBackgroundSafety()`,
// and the iOS-only observer storage.
// Doesn't own: model load/unload (`CastModel.swift` core) or GPU cleanup
// (`CastModel+GPUSafety.swift`).

import Foundation
import MLX
import os

#if canImport(UIKit) && os(iOS)
    import UIKit
#endif

// MARK: - Public API (cross-platform)

public extension CastModel {
    /// Cancel every in-flight generation immediately. Each call site receives
    /// ``CastError/cancelled(partialOutput:)`` (or ``CastError/generationFailed(_:)``
    /// if cancellation lands before the generation registered itself).
    ///
    /// Safe to call from any thread; idempotent if there is no work in flight.
    func abortInFlight() {
        let cancels = _inFlight.withLock { dict -> [@Sendable () -> Void] in
            let values = Array(dict.values)
            dict.removeAll()
            return values
        }
        for cancel in cancels {
            cancel()
        }
    }
}

#if canImport(UIKit) && os(iOS)

    // MARK: - iOS background lifecycle

    private final class _LifecycleObservers: @unchecked Sendable {
        let didEnterBackground: NSObjectProtocol
        let willResignActive: NSObjectProtocol
        let memoryWarning: NSObjectProtocol

        init(
            didEnterBackground: NSObjectProtocol,
            willResignActive: NSObjectProtocol,
            memoryWarning: NSObjectProtocol
        ) {
            self.didEnterBackground = didEnterBackground
            self.willResignActive = willResignActive
            self.memoryWarning = memoryWarning
        }
    }

    /// Per-CastModel observer storage. Keyed by `ObjectIdentifier` so the entry
    /// is cleared on `disableBackgroundSafety()` or `unload()`.
    private let _observers = OSAllocatedUnfairLock<[ObjectIdentifier: _LifecycleObservers]>(
        initialState: [:]
    )

    public extension CastModel {
        /// Subscribe to iOS app lifecycle notifications and use them to keep
        /// generation safe across background transitions:
        ///
        /// - `willResignActive` → free non-essential GPU memory (`Memory.clearCache()`).
        ///   The user may come right back; running work is *not* cancelled.
        /// - `didEnterBackground` → cancel every in-flight generation (the
        ///   sampler stops, the call throws ``CastError/cancelled(partialOutput:)``)
        ///   and synchronize the GPU. **Critical**: iOS terminates Metal users
        ///   that hold the GPU while backgrounded.
        /// - `didReceiveMemoryWarning` → free GPU cache; running work is not
        ///   cancelled.
        ///
        /// Idempotent — calling twice does not register duplicate observers.
        /// No-op on macOS / non-UIKit platforms.
        func enableBackgroundSafety() {
            let key = ObjectIdentifier(self)
            let center = NotificationCenter.default
            let weakSelf = WeakBox(self)

            let didEnter = center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: nil
            ) { _ in
                guard let model = weakSelf.value else { return }
                model.abortInFlight()
                model.cleanupGPU()
            }

            let willResign = center.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: nil
            ) { _ in
                Memory.clearCache()
            }

            let memWarn = center.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: nil
            ) { _ in
                Memory.clearCache()
            }

            let observers = _LifecycleObservers(
                didEnterBackground: didEnter,
                willResignActive: willResign,
                memoryWarning: memWarn
            )

            // Single atomic check-and-insert: prevents two concurrent callers
            // from both passing a check then both registering observer trios.
            let inserted = _observers.withLock { dict -> Bool in
                guard dict[key] == nil else { return false }
                dict[key] = observers
                return true
            }

            if !inserted {
                center.removeObserver(didEnter)
                center.removeObserver(willResign)
                center.removeObserver(memWarn)
            }
        }

        /// Detach all lifecycle observers registered by ``enableBackgroundSafety()``.
        /// Safe to call without a prior `enable…`.
        func disableBackgroundSafety() {
            let key = ObjectIdentifier(self)
            let removed = _observers.withLock { dict -> _LifecycleObservers? in
                dict.removeValue(forKey: key)
            }
            guard let removed else { return }
            let center = NotificationCenter.default
            center.removeObserver(removed.didEnterBackground)
            center.removeObserver(removed.willResignActive)
            center.removeObserver(removed.memoryWarning)
        }
    }

    private final class WeakBox<T: AnyObject>: @unchecked Sendable {
        weak var value: T?
        init(_ value: T) {
            self.value = value
        }
    }

#else

    // MARK: - Non-iOS stubs

    public extension CastModel {
        /// No-op on this platform. iOS-only.
        func enableBackgroundSafety() {}
        /// No-op on this platform. iOS-only.
        func disableBackgroundSafety() {}
    }

#endif
