// What this shows: the three ways to bound a Cast generation:
//
// 1. CastConfiguration.timeout — wall-clock deadline; throws CastError.timedOut.
// 2. didGenerate as a hard token budget — return .stop once the budget is hit.
//    Surfaces as a normal decoded value (or .repairFailed if the partial JSON
//    can't be patched up).
// 3. Task.cancel() on the wrapping task — throws CastError.cancelled, carrying
//    whatever bytes the model produced before the cancel landed.

import Cast
import Foundation

@Castable
struct LongStory {
    var title: String = ""
    var paragraphs: [String] = []
}

@main
enum Cancellation {
    static func main() async throws {
        let model = try await CastModel.load("mlx-community/Llama-3.2-3B-Instruct-4bit")
        let prompt = "Write a long fantasy short story with at least 8 paragraphs."

        // Scenario 1: wall-clock timeout.
        var timedConfig = CastConfiguration()
        timedConfig.timeout = .seconds(2)
        do {
            let story: LongStory = try await model.cast(prompt, config: timedConfig)
            print("[timeout] finished within deadline:", story)
        } catch let CastError.timedOut(partial) {
            print("[timeout] hit the 2s deadline; partial:", partial?.prefix(120) as Any)
        }

        // Scenario 2: token budget via didGenerate.
        do {
            let story: LongStory = try await model.cast(prompt) { tokens in
                tokens > 50 ? .stop : .more
            }
            print("[budget] decoded after early stop:", story)
        } catch let CastError.repairFailed(raw, reason) {
            print("[budget] truncated beyond repair (\(reason)). partial:", raw.prefix(120))
        } catch let CastError.decodingFailed(raw, error) {
            print("[budget] repaired but decode failed:", error, "partial:", raw.prefix(120))
        }

        // Scenario 3: external Task.cancel.
        let task = Task<LongStory, Error> { try await model.cast(prompt) }
        try await Task.sleep(for: .milliseconds(200))
        task.cancel()
        do {
            let story = try await task.value
            print("[cancel] decoded before cancel landed:", story)
        } catch let CastError.cancelled(partial) {
            print("[cancel] cancelled; partial:", partial?.prefix(120) as Any)
        } catch {
            print("[cancel] other error:", error)
        }
    }
}
