// Locks the single-import contract: consumers should be able to write only
// `import Cast` and still reach `OrderedDictionary` (Collections) and
// `JSONSchema`. Compilation alone is the assertion — if either re-export in
// `Sources/Cast/API/Castable.swift` is removed, this file stops compiling.

import Cast
import Testing

@Suite("Re-exports")
struct ReExportsTest {
    @Test("OrderedDictionary and JSONSchema reachable via `import Cast` only")
    func reExportedSymbolsAreReachable() {
        var dict = OrderedDictionary<String, Int>()
        dict["a"] = 1
        #expect(dict["a"] == 1)

        let schema = JSONSchema.string()
        #expect(String(describing: schema).isEmpty == false)
    }
}
