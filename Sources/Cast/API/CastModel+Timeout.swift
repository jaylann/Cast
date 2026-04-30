import Foundation

/// Race a generation against a wall-clock timeout. When the timeout fires,
/// the in-flight generation is cancelled — its `didGenerate` polls
/// `Task.isCancelled` and returns `.stop`, so the model exits cleanly.
///
/// Returns the generation's result on success; throws
/// ``CastError/timedOut(partialOutput:)`` when the deadline is hit first.
/// `nil` timeout disables the race.
func withGenerationTimeout<T: Sendable>(
    _ timeout: Duration?,
    operation: @Sendable @escaping () async throws -> T
) async throws -> T {
    guard let timeout else {
        return try await operation()
    }
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(for: timeout)
            throw CastError.timedOut(partialOutput: nil)
        }
        defer { group.cancelAll() }
        guard let result = try await group.next() else {
            throw CastError.timedOut(partialOutput: nil)
        }
        return result
    }
}

extension CastModel {
    /// Wrap a generation operation in a child Task and register its `cancel`
    /// in ``CastModel/_inFlight`` for the duration of the call. External
    /// `Task.cancel()` propagates via `withTaskCancellationHandler`; iOS
    /// background notifications and ``abortInFlight()`` use the registry
    /// directly.
    func withInFlightRegistration<T: Sendable>(
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        let id = UUID()
        let task = Task<T, Error> {
            try await operation()
        }
        _inFlight.withLock { dict in
            dict[id] = { task.cancel() }
        }
        defer {
            _inFlight.withLock { dict in
                _ = dict.removeValue(forKey: id)
            }
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }
}
