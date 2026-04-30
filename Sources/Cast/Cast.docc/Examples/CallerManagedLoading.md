# CallerManagedLoading

building CastModel from a caller-managed ModelContainer via
init(wrapping:configuration:). Use this when the host app already owns the
container — for example, the same model serves both Cast structured output
and free-form chat, or you want a single download to back several CastModels.

## Source

Full source: [Examples/Sources/CallerManagedLoading/main.swift](https://github.com/jaylann/Cast/blob/main/Examples/Sources/CallerManagedLoading/main.swift)

```swift
// What this shows: building CastModel from a caller-managed ModelContainer via
// init(wrapping:configuration:). Use this when the host app already owns the
// container — for example, the same model serves both Cast structured output
// and free-form chat, or you want a single download to back several CastModels.

import Cast
import Collections
import Foundation
import JSONSchema
import MLXLLM
import MLXLMCommon

@Castable
struct Note {
    var headline: String = ""
    var body: String = ""
}

@main
enum CallerManagedLoading {
    static func main() async throws {
        let modelId = "mlx-community/Llama-3.2-3B-Instruct-4bit"
        let configuration = ModelConfiguration(id: modelId)
        let container = try await LLMModelFactory.shared.loadContainer(configuration: configuration)

        let m1 = CastModel(wrapping: container, configuration: configuration)
        let m2 = CastModel(wrapping: container, configuration: configuration)

        let a: Note = try await m1.cast("Write a one-line note about apples.")
        let b: Note = try await m2.cast("Write a one-line note about bicycles.")
        print("[m1]", a)
        print("[m2]", b)

        m1.unload()
        let c: Note = try await m2.cast("Write a one-line note about clouds.")
        print("[m2 after m1.unload]", c)
    }
}

// Prefer init(wrapping:) over CastModel.load(_:) when:
//  - the host app already manages ModelContainer lifetime,
//  - several components share one downloaded model,
//  - you want custom progress / caching around loadContainer.
//
// unload() on one CastModel does not free the underlying container while
// another CastModel still references it — the second model keeps working.
```
