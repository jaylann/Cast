import Cast
import Collections
import JSONSchema

@Castable
struct Recipe {
    @Description("Short, punchy title")
    var title: String = ""

    @MaxCount(8)
    var ingredients: [String] = []

    @CastRange(1 ... 60)
    var prepMinutes: Int = 0
}

enum Sentiment: String, CastEnum, CaseIterable {
    case positive, negative, neutral
}

@Castable
struct InvoiceFields {
    @Description("Invoice number from the document")
    var invoiceNumber: String = ""

    @Description("Total amount in USD")
    var totalUSD: Double = 0
}
