// What this shows: extract structured fields from a block of unstructured text via model.extract(from:as:instruction:).

import Cast
import Collections
import Foundation
import JSONSchema

@Castable
struct InvoiceFields {
    var invoiceNumber: String = ""
    var vendor: String = ""
    var totalUSD: Double = 0
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

// Sample output (manual run, will vary by model):
// InvoiceFields(invoiceNumber: "INV-7421", vendor: "ACME Corp.", totalUSD: 1250.0)
