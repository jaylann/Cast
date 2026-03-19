---
paths:
  - "Sources/Cast/Sampler/**/*.swift"
  - "Sources/Cast/Tokenizer/**/*.swift"
---

# MLX GPU Safety for Library Consumers

## Cast's Responsibility
Cast manages GPU operations during constrained generation. Internally:
- Generation methods are `async` and support `Task` cancellation
- `Task.isCancelled` checked between generation steps
- No global GPU state retained beyond cached tokenizer mappings

## Consumer's Responsibility
Cast does **not** manage app lifecycle. Consumers (iOS apps) must:
1. **Cancel generation on background transition** — call `Task.cancel()` on the generation task
2. **Wait for GPU work to complete** — `Stream.gpu.synchronize()` in `.inactive` before `.background`
3. **Never call Cast generation methods from background state**

## GPU Operation Best Practices
- `CastModel.cast()` and related methods are the only GPU entry points
- Tokenizer cache is CPU-only — safe to access from any state
- Grammar compilation is CPU-only — no GPU concerns
- Model loading triggers GPU allocation — do not call from background

## Memory Pressure
- Cast does not auto-unload models — consumer decides when to release `CastModel`
- Setting `CastModel` reference to `nil` triggers model unload
- `GPU.clearCache()` should only be called when no generation is in progress

## References
- [MLX Swift Issue #230](https://github.com/ml-explore/mlx-swift-examples/issues/230) — Background GPU crashes
- [Apple Metal Background Docs](https://developer.apple.com/documentation/metal/preparing-your-metal-app-to-run-in-the-background)
