# CustomModelSource

load CastModel from a local directory or a custom HF mirror endpoint.

## Source

Full source: [Examples/Sources/CustomModelSource/main.swift](https://github.com/jaylann/Cast/blob/main/Examples/Sources/CustomModelSource/main.swift)

```swift
// What this shows: load CastModel from a local directory or a custom HF mirror endpoint.

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
enum CustomModelSource {
    static func main() async throws {
        // 1. Air-gapped / pre-downloaded model on disk.
        let localPath = URL(fileURLWithPath: "/Users/me/Models/llama-3.2-3b-4bit")
        let local = try await CastModel.load(.directory(localPath))
        let note: Note = try await local.cast("One-line note about local models.")
        print("[directory]", note)

        // 2. Custom HF-shaped endpoint — corporate mirror, self-hosted CDN, proxy.
        guard let endpoint = URL(string: "https://hf-mirror.corp.example.com") else { return }
        let mirror = try await CastModel.load(
            .customEndpoint(
                id: "internal/llama-3.2-3b-4bit",
                endpoint: endpoint,
                revision: "v1.0"
            )
        )
        let mirrored: Note = try await mirror.cast("One-line note about mirrors.")
        print("[customEndpoint]", mirrored)
    }
}

// .bundle(_:resourceName:) is the fourth ModelSource case — point at a model
// directory shipped inside an app's resource folder. Useful for fully offline
// apps that ship the weights alongside the binary.
```
