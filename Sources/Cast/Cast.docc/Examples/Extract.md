# Extract

extract structured fields from a block of unstructured text via model.extract(from:as:instruction:).

## Source

Full source: [Examples/Sources/Extract/main.swift](https://github.com/jaylann/Cast/blob/main/Examples/Sources/Extract/main.swift)

```swift
// What this shows: extract structured fields from a block of unstructured text via model.extract(from:as:instruction:).

import Cast
import Collections
import Foundation
import JSONSchema

/// Optional fields demonstrate the no-invention contract: a missing
/// value in the source can decode to `nil` rather than being hallucinated.
@Castable
struct InvoiceFields {
    var invoiceNumber: String?
    var vendor: String?
    var totalUSD: Double?
}

@main
enum Extract {
    static func main() async throws {
        let model = try await CastModel.load("mlx-community/Llama-3.2-3B-Instruct-4bit")

        let invoice = """
        ACME Corp.
        Invoice Number: INV-7421
        Date: 2025-03-12
        Description: Consulting services
        Total Due: $1,250.00 USD
        """

        let fields: InvoiceFields = try await model.extract(
            from: invoice,
            instruction: "Extract the invoice number, vendor name, and total in USD."
        )

        print(fields)
    }
}
```
