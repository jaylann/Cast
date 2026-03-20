import Foundation
import MLX
@preconcurrency import MLXLMCommon
import os

// MARK: - Global MLX Error Handler

/// Captures errors from MLX C++ scheduler threads where Swift error handlers aren't visible.
private let mlxGlobalErrorLock = OSAllocatedUnfairLock(initialState: String?.none)

private let globalMLXErrorHandler: @convention(c) (UnsafePointer<CChar>?, UnsafeMutableRawPointer?) -> Void = { message, _ in
    let errorMessage = message.map { String(cString: $0) } ?? "Unknown MLX error"
    mlxGlobalErrorLock.withLock { $0 = errorMessage }
}

private let _setupGlobalErrorHandler: Void = {
    setErrorHandler(globalMLXErrorHandler)
}()

// MARK: - GPU Safety Extensions

extension CastModel {

    static func ensureErrorHandler() {
        _ = _setupGlobalErrorHandler
    }

    static func checkAndClearMLXGlobalError() -> String? {
        mlxGlobalErrorLock.withLock { error in
            let result = error
            error = nil
            return result
        }
    }

    func cleanupGPU() {
        try? withError {
            Stream.gpu.synchronize()
            Memory.clearCache()
        }
    }
}
