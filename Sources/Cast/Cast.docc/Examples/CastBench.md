# CastBench

built-in benchmarking for Cast — measure tok/s, latency,
grammar overhead, and (optionally) compare against unconstrained generation.

## Source

Full source: [Examples/Sources/CastBench/main.swift](https://github.com/jaylann/Cast/blob/main/Examples/Sources/CastBench/main.swift)

```swift
// What this shows: built-in benchmarking for Cast — measure tok/s, latency,
// grammar overhead, and (optionally) compare against unconstrained generation.

import Cast
import Collections
import Foundation
import JSONSchema

@Castable
struct Person {
    var name: String = ""
    var age: Int = 0
    var occupation: String = ""
}

@main
enum CastBenchExample {
    static func main() async throws {
        let model = try await CastModel.load("mlx-community/Llama-3.2-1B-Instruct-4bit")
        let bench = CastBench(model)

        var config = CastConfiguration()
        config.maxTokens = 128

        let prompt = "Marie Curie was a 66-year-old physicist and chemist."

        // 1) Single-mode benchmark — constrained throughput / latency.
        let result = try await bench.run(
            type: Person.self,
            prompt: prompt,
            iterations: 5,
            config: config
        )

        print("=== run() — table ===")
        print(result.formatted(as: .table))
        print()
        print("=== run() — markdown ===")
        print(result.formatted(as: .markdown))
        print()
        print("=== run() — json ===")
        print(result.formatted(as: .json))
        print()

        // 2) Comparison — constrained vs. unconstrained, plus the rate at
        // which raw (unconstrained) output happens to decode into Person.
        let comparison = try await bench.compare(
            type: Person.self,
            prompt: prompt,
            iterations: 5,
            config: config
        )

        print("=== compare() — table ===")
        print(comparison.formatted(as: .table))
        print()
        print("=== compare() — markdown ===")
        print(comparison.formatted(as: .markdown))
        print()
        print("=== compare() — json ===")
        print(comparison.formatted(as: .json))
    }
}

// Notes:
//  - `run(...)` runs `iterations` constrained calls plus a single unconstrained
//    shadow call to estimate `grammarOverheadMs` (per-token, in milliseconds).
//  - `compare(...)` runs `iterations` of each path and additionally reports
//    `unconstrainedValidRate` — the fraction of raw outputs that decoded into
//    your type without `JSONRepair`. A handy proxy for "how much does the
//    grammar buy me on this prompt?".
//  - Both methods honor `CastConfiguration.timeout` and `Task.cancel()`.
```
