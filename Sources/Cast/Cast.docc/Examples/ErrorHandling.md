# ErrorHandling

every CastError case and a recommended user-facing reaction.
Tip: call prepare(T.self) at app start to surface schemaGenerationFailed and
unsupportedType errors before the user ever issues a request.

## Source

Full source: [Examples/Sources/ErrorHandling/main.swift](https://github.com/jaylann/Cast/blob/main/Examples/Sources/ErrorHandling/main.swift)

```swift
// What this shows: every CastError case and a recommended user-facing reaction.
// Tip: call prepare(T.self) at app start to surface schemaGenerationFailed and
// unsupportedType errors before the user ever issues a request.

import Cast
import Foundation

@Castable
struct Quote {
    var text: String = ""
    var author: String = ""
}

@main
enum ErrorHandling {
    static func main() async {
        // Single cold load — reused for decodingFailed, then unloaded for modelNotLoaded.
        let model: CastModel
        do {
            model = try await CastModel.load("mlx-community/Llama-3.2-3B-Instruct-4bit")
        } catch {
            print("[load] unexpected:", error)
            return
        }

        // 1. decodingFailed: tiny maxTokens forces truncated JSON.
        do {
            var cfg = CastConfiguration()
            cfg.maxTokens = 1
            _ = try await model.cast("Give me a long famous quote.", as: Quote.self, config: cfg)
        } catch let CastError.decodingFailed(raw, error) {
            print("[decodingFailed] surface 'try again' to user. raw:", raw.prefix(60), "err:", error)
        } catch {
            print("[decodingFailed] unexpected:", error)
        }

        // 2. modelNotLoaded: cast() called after unload().
        do {
            model.unload()
            _ = try await model.cast("anything", as: Quote.self)
        } catch CastError.modelNotLoaded {
            print("[modelNotLoaded] tell user the model needs to load again, retry")
        } catch {
            print("[modelNotLoaded] unexpected:", error)
        }

        // 3. schemaGenerationFailed: SchemaGenerator wraps any internal error here.
        //    (Hard to provoke from the public surface today — most schema issues are
        //    caught at compile time by the @Castable macro.)
        do {
            _ = try SchemaGenerator.schema(for: Quote.self)
            print("[schemaGenerationFailed] not triggered — Quote is well-formed")
        } catch let CastError.schemaGenerationFailed(detail) {
            print("[schemaGenerationFailed] log+report, ship a fix:", detail)
        } catch {
            print("[schemaGenerationFailed] other error:", error)
        }

        // 4. unsupportedType: declared in CastError; reserved for future
        //    schema-generation paths. Catch it defensively so a future ship
        //    doesn't silently fall through to a generic error message.
        //    (No reliable trigger today.)
        print("[unsupportedType] reserved — handle alongside schemaGenerationFailed")

        // 5. generationFailed: wraps any error MLX throws during decoding.
        //    Hard to force without a corrupt model; catch it as the fallback.
        print("[generationFailed] surfaced if MLX itself errors mid-generation")
    }
}
```
