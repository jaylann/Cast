// What this shows: classify(_:as:) routes through a CastEnum with both
// String- and Int-backed raw values. classify hard-caps maxTokens to 10 and
// forces temperature to 0.0, so it's strictly faster than a full cast() when
// you only need a single label.

import Cast
import Foundation

enum Sentiment: String, CastEnum {
    case positive, negative, neutral
}

enum Priority: Int, CastEnum {
    case low = 0, medium = 1, high = 2
}

@main
enum Classify {
    static func main() async throws {
        let model = try await CastModel.load("mlx-community/Llama-3.2-3B-Instruct-4bit")

        let sentiment: Sentiment = try await model.classify(
            "I absolutely loved the new espresso machine, best buy of the year."
        )
        print("sentiment:", sentiment)

        let priority: Priority = try await model.classify(
            "Production database is down — every request is 500ing."
        )
        print("priority:", priority)
    }
}

// Sample output (illustrative):
// sentiment: positive
// priority: high
