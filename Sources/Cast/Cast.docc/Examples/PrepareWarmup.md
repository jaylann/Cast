# PrepareWarmup

what prepare() actually buys you. Three timings in one run:
cold (no prepare), warm (after prepare), warm (after a prior cast). The
(model, type) tokenizer cache is populated by either prepare() or the first
cast(), so the second cast is fast either way — prepare() lets you pay that
cost up front instead of inside your first user-visible call.

## Source

Full source: [Examples/Sources/PrepareWarmup/main.swift](https://github.com/jaylann/Cast/blob/main/Examples/Sources/PrepareWarmup/main.swift)

```swift
// What this shows: what prepare() actually buys you. Three timings in one run:
// cold (no prepare), warm (after prepare), warm (after a prior cast). The
// (model, type) tokenizer cache is populated by either prepare() or the first
// cast(), so the second cast is fast either way — prepare() lets you pay that
// cost up front instead of inside your first user-visible call.

import Cast
import Collections
import Foundation
import JSONSchema

@Castable
struct Note {
    var headline: String = ""
    var body: String = ""
}

@main
enum PrepareWarmup {
    static func main() async throws {
        let model = try await CastModel.load("mlx-community/Llama-3.2-3B-Instruct-4bit")
        let prompt = "Write a short note about the weather today."

        var t = Date()
        _ = try await model.cast(prompt, as: Note.self)
        print(String(format: "[1] cold-no-prepare:        %.3fs", Date().timeIntervalSince(t)))

        try await model.prepare(Note.self)

        t = Date()
        _ = try await model.cast(prompt, as: Note.self)
        print(String(format: "[2] warm-after-prepare:     %.3fs", Date().timeIntervalSince(t)))

        t = Date()
        _ = try await model.cast(prompt, as: Note.self)
        print(String(format: "[3] warm-after-first-cast:  %.3fs", Date().timeIntervalSince(t)))
    }
}

// Sample timings (M-series, 4-bit Llama 3.2, fill in your own):
// [1] cold-no-prepare:        x.xxxs
// [2] warm-after-prepare:     x.xxxs
// [3] warm-after-first-cast:  x.xxxs
//
// Note: this is a demonstration, not a benchmark — see #38/#39 for those.
```
