@testable import Cast
import Collections
import JSONSchema
import Testing

@Castable
struct InvoiceFields {
    var invoiceNumber: String = ""
    var totalUSD: Double = 0
}

@Suite("Extract")
struct ExtractTests {
    @Test("extract throws modelNotLoaded when no model")
    func extractNoModel() async {
        let model = CastModel(_testContainer: nil)
        await #expect(throws: CastError.self) {
            let _: InvoiceFields = try await model.extract(
                from: "Invoice #1 total $10",
                instruction: "Extract."
            )
        }
    }

    @Test("extract end-to-end on a small invoice", .requiresMetal)
    func extractInvoice() async throws {
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
            instruction: "Extract the invoice number and total in USD."
        )

        #expect(!fields.invoiceNumber.isEmpty)
        #expect(fields.totalUSD > 0)
    }
}
