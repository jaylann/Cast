import Foundation
import Testing

extension Trait where Self == Testing.ConditionTrait {
    /// Skip when running in CI (GitHub Actions sets `CI=true`). Used for tests
    /// that require Metal/MLX runtime — see issue #75. GitHub-hosted macOS
    /// runners are virtualized and can't load MLX's `default.metallib`.
    static var requiresMetal: Self {
        .enabled(
            if: ProcessInfo.processInfo.environment["CI"] == nil,
            "Skipped on CI: requires Metal/MLX runtime (issue #75)"
        )
    }
}
