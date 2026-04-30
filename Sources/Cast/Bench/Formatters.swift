import Foundation

/// Pure formatters for ``BenchmarkResult`` and ``BenchmarkComparison``.
/// Pure: no side effects, no I/O. Deterministic for a given input.
enum BenchmarkFormatters {
    // MARK: - BenchmarkResult

    static func formatTable(_ result: BenchmarkResult) -> String {
        let rows: [(String, String)] = [
            ("Iterations", String(result.iterations)),
            ("Avg latency", formatDuration(result.averageLatency)),
            ("Avg tokens", formatTokens(result.averageTokenCount)),
            ("Tokens/sec", formatRate(result.tokensPerSecond)),
            ("Grammar overhead", formatOverheadMs(result.grammarOverheadMs))
        ]
        return renderTwoColumnTable(rows: rows, headerLabel: "Metric", headerValue: "Value")
    }

    static func formatMarkdown(_ result: BenchmarkResult) -> String {
        let rows: [(String, String)] = [
            ("Iterations", String(result.iterations)),
            ("Avg latency", formatDuration(result.averageLatency)),
            ("Avg tokens", formatTokens(result.averageTokenCount)),
            ("Tokens/sec", formatRate(result.tokensPerSecond)),
            ("Grammar overhead", formatOverheadMs(result.grammarOverheadMs))
        ]
        var lines: [String] = []
        lines.append("| Metric | Value |")
        lines.append("| --- | --- |")
        for (k, v) in rows {
            lines.append("| \(k) | \(v) |")
        }
        return lines.joined(separator: "\n")
    }

    static func formatJSON(_ result: BenchmarkResult) -> String {
        encodeJSON(result)
    }

    // MARK: - BenchmarkComparison

    static func formatTable(_ comparison: BenchmarkComparison) -> String {
        let rows: [(String, String, String)] = [
            ("Iterations", String(comparison.constrained.iterations), String(comparison.unconstrained.iterations)),
            (
                "Avg latency",
                formatDuration(comparison.constrained.averageLatency),
                formatDuration(comparison.unconstrained.averageLatency)
            ),
            (
                "Avg tokens",
                formatTokens(comparison.constrained.averageTokenCount),
                formatTokens(comparison.unconstrained.averageTokenCount)
            ),
            (
                "Tokens/sec",
                formatRate(comparison.constrained.tokensPerSecond),
                formatRate(comparison.unconstrained.tokensPerSecond)
            )
        ]

        var sectionRows = rows
        sectionRows.append((
            "Overhead",
            String(format: "+%.2f%%", comparison.overheadPercent),
            "—"
        ))
        sectionRows.append((
            "Valid rate",
            "100%",
            String(format: "%.1f%%", comparison.unconstrainedValidRate * 100)
        ))

        return renderThreeColumnTable(
            rows: sectionRows,
            headers: ("Metric", "Constrained", "Unconstrained")
        )
    }

    static func formatMarkdown(_ comparison: BenchmarkComparison) -> String {
        var lines: [String] = []
        lines.append("| Metric | Constrained | Unconstrained |")
        lines.append("| --- | --- | --- |")
        lines.append("| Iterations | \(comparison.constrained.iterations) | \(comparison.unconstrained.iterations) |")
        lines
            .append(
                "| Avg latency | \(formatDuration(comparison.constrained.averageLatency)) | \(formatDuration(comparison.unconstrained.averageLatency)) |"
            )
        lines
            .append(
                "| Avg tokens | \(formatTokens(comparison.constrained.averageTokenCount)) | \(formatTokens(comparison.unconstrained.averageTokenCount)) |"
            )
        lines
            .append(
                "| Tokens/sec | \(formatRate(comparison.constrained.tokensPerSecond)) | \(formatRate(comparison.unconstrained.tokensPerSecond)) |"
            )
        lines.append("| Overhead | +\(String(format: "%.2f", comparison.overheadPercent))% | — |")
        lines.append("| Valid rate | 100% | \(String(format: "%.1f", comparison.unconstrainedValidRate * 100))% |")
        return lines.joined(separator: "\n")
    }

    static func formatJSON(_ comparison: BenchmarkComparison) -> String {
        encodeJSON(comparison)
    }

    // MARK: - Internals

    private static func encodeJSON(_ value: some Encodable) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value),
              let str = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return str
    }

    private static func formatDuration(_ duration: Duration) -> String {
        let comps = duration.components
        let seconds = Double(comps.seconds) + Double(comps.attoseconds) / 1e18
        if seconds < 1 {
            return String(format: "%.0f ms", seconds * 1000)
        }
        return String(format: "%.3f s", seconds)
    }

    private static func formatTokens(_ tokens: Double) -> String {
        String(format: "%.1f", tokens)
    }

    private static func formatRate(_ rate: Double) -> String {
        String(format: "%.2f tok/s", rate)
    }

    private static func formatOverheadMs(_ ms: Double) -> String {
        String(format: "%.3f ms/tok", ms)
    }

    // MARK: - Table renderers

    private static func renderTwoColumnTable(
        rows: [(String, String)],
        headerLabel: String,
        headerValue: String
    ) -> String {
        let labelWidth = max(headerLabel.count, rows.map(\.0.count).max() ?? 0)
        let valueWidth = max(headerValue.count, rows.map(\.1.count).max() ?? 0)
        let separator = "+\(String(repeating: "-", count: labelWidth + 2))+\(String(repeating: "-", count: valueWidth + 2))+"

        var lines: [String] = []
        lines.append(separator)
        lines
            .append(
                "| \(headerLabel.padding(toLength: labelWidth, withPad: " ", startingAt: 0)) | \(headerValue.padding(toLength: valueWidth, withPad: " ", startingAt: 0)) |"
            )
        lines.append(separator)
        for (k, v) in rows {
            let kPad = k.padding(toLength: labelWidth, withPad: " ", startingAt: 0)
            let vPad = v.padding(toLength: valueWidth, withPad: " ", startingAt: 0)
            lines.append("| \(kPad) | \(vPad) |")
        }
        lines.append(separator)
        return lines.joined(separator: "\n")
    }

    private static func renderThreeColumnTable(
        rows: [(String, String, String)],
        headers: (String, String, String)
    ) -> String {
        let w0 = max(headers.0.count, rows.map(\.0.count).max() ?? 0)
        let w1 = max(headers.1.count, rows.map(\.1.count).max() ?? 0)
        let w2 = max(headers.2.count, rows.map(\.2.count).max() ?? 0)
        let separator = "+\(String(repeating: "-", count: w0 + 2))+\(String(repeating: "-", count: w1 + 2))+\(String(repeating: "-", count: w2 + 2))+"

        func pad(_ s: String, _ w: Int) -> String {
            s.padding(toLength: w, withPad: " ", startingAt: 0)
        }

        var lines: [String] = []
        lines.append(separator)
        lines.append("| \(pad(headers.0, w0)) | \(pad(headers.1, w1)) | \(pad(headers.2, w2)) |")
        lines.append(separator)
        for (a, b, c) in rows {
            lines.append("| \(pad(a, w0)) | \(pad(b, w1)) | \(pad(c, w2)) |")
        }
        lines.append(separator)
        return lines.joined(separator: "\n")
    }
}
