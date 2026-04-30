import Foundation

/// A snapshot of a still-streaming ``CastModel/castStream(_:as:system:config:)`` call.
///
/// `value` is the partially-decoded form of `T` (every field Optional, fields
/// that haven't been emitted yet are `nil`). `progress` reflects how close the
/// generation is to its `maxTokens` budget, clamped to `0...1`. `tokenCount`
/// is the number of tokens produced so far.
public struct PartialResult<T: Castable>: Sendable {
    /// Decoded snapshot. Properties not yet emitted are `nil`.
    public let value: T.PartiallyGenerated
    /// Tokens consumed divided by ``CastConfiguration/maxTokens``, clamped to `0...1`.
    public let progress: Double
    /// Number of tokens generated up to (and including) this snapshot.
    public let tokenCount: Int

    public init(value: T.PartiallyGenerated, progress: Double, tokenCount: Int) {
        self.value = value
        self.progress = progress
        self.tokenCount = tokenCount
    }
}
