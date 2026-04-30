import Foundation

/// Best-effort repair for JSON output that was cut short mid-generation
/// (timeout, ``CastConfiguration/maxTokens``, cancellation, background
/// transition). The grammar guarantees prefix-validity but not termination,
/// so a truncated stream is *almost* valid JSON missing only its tail.
///
/// `JSONRepair` does a single left-to-right scan to balance unclosed strings
/// and containers, drop dangling key/value fragments, and trim the trailing
/// comma. Repaired output is validated with `JSONSerialization` before it is
/// handed back; unrecoverable input surfaces as ``RepairResult/unrecoverable``.
public enum JSONRepair {
    /// Outcome of a repair attempt.
    public enum RepairResult: Sendable, Equatable {
        /// Input is already balanced JSON. Decoder can use it as-is.
        case ok(String)
        /// Input was repaired. The associated string is the repaired JSON;
        /// the second value lists the fixes applied (for diagnostics).
        case repaired(String, [String])
        /// Input cannot be repaired into valid JSON.
        case unrecoverable(reason: String)
    }

    /// Attempt to repair `raw` into syntactically valid JSON.
    public static func repair(_ raw: String) -> RepairResult {
        var scratch: [String] = []
        let scan: ScanState
        do {
            scan = try Scanner.scan(raw)
        } catch let error as RepairError {
            return .unrecoverable(reason: error.reason)
        } catch {
            return .unrecoverable(reason: error.localizedDescription)
        }

        if scan.containerStack.isEmpty, !scan.inString {
            // Already balanced; let the decoder validate semantics.
            if isValidJSON(raw) {
                return .ok(raw)
            }
            return .unrecoverable(reason: "balanced but invalid JSON")
        }

        var repaired = scan.truncated

        if scan.inString {
            // Truncated mid-string: close the string. If the cut landed
            // inside a partial `\uXXXX` escape, drop the partial escape first.
            if let backedOff = backOffPartialUnicodeEscape(repaired) {
                repaired = backedOff
                scratch.append("dropped partial \\u escape")
            } else if endsInDanglingBackslash(repaired) {
                repaired.removeLast()
                scratch.append("dropped trailing backslash")
            }
            repaired.append("\"")
            scratch.append("closed unterminated string")
        }

        // Strip dangling key/value fragments and trailing commas, then close
        // each open container in stack order.
        var stack = scan.containerStack
        while !stack.isEmpty {
            let frame = stack.removeLast()
            repaired = trimDanglingFragment(in: repaired, frame: frame, scratch: &scratch)
            switch frame.kind {
            case .object:
                repaired.append("}")
            case .array:
                repaired.append("]")
            }
            scratch.append("closed \(frame.kind == .object ? "object" : "array")")
        }

        guard isValidJSON(repaired) else {
            return .unrecoverable(reason: "repaired JSON failed validation")
        }
        return .repaired(repaired, scratch)
    }

    // MARK: - Validation gate

    private static func isValidJSON(_ string: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil
    }
}

// MARK: - Scanner

private enum ContainerKind {
    case object
    case array
}

private struct ContainerFrame {
    let kind: ContainerKind
    /// Position (utf-8 byte offset) where the container opened.
    let openOffset: Int
    /// Position of the most recent comma inside this frame, or `nil`.
    var lastCommaOffset: Int?
    /// Position of the most recent colon inside this frame (only meaningful
    /// for objects), or `nil` if no key/value pair has been started.
    var lastColonOffset: Int?
    /// Offset where the current key began (objects only). Reset to `nil`
    /// once the colon for that key is consumed.
    var pendingKeyStart: Int?
    /// Offset where the current value began (objects only, post-colon, or
    /// arrays — any element). Reset to `nil` once the value is fully read
    /// and a comma is consumed.
    var pendingValueStart: Int?
}

private struct ScanState {
    /// The raw input, possibly trimmed of trailing whitespace.
    let truncated: String
    let containerStack: [ContainerFrame]
    let inString: Bool
}

private struct RepairError: Error {
    let reason: String
}

private enum Scanner {
    /// Walk `input` left-to-right and return the in-flight state at EOF.
    static func scan(_ input: String) throws -> ScanState {
        // Trim trailing whitespace so we don't add closers after spaces.
        var trimmed = input
        while let last = trimmed.unicodeScalars.last, CharacterSet.whitespacesAndNewlines.contains(last) {
            trimmed.unicodeScalars.removeLast()
        }
        let bytes = Array(trimmed.utf8)
        var stack: [ContainerFrame] = []
        var inString = false
        var escape = false
        // Tracks whether the most recently consumed token in an object frame
        // was a colon — i.e., we're waiting on a value for the current key.
        var i = 0
        while i < bytes.count {
            let byte = bytes[i]
            if inString {
                if escape {
                    escape = false
                } else if byte == 0x5C { // backslash
                    escape = true
                } else if byte == 0x22 { // closing quote
                    inString = false
                    if var top = stack.popLast() {
                        if top.kind == .object, top.pendingKeyStart != nil, top.lastColonOffset == nil {
                            // Just finished reading the key.
                        } else if top.pendingValueStart == nil {
                            // First non-whitespace thing inside this frame is a string;
                            // treat it as the start of a value (array element or unkeyed
                            // object value will be flagged later).
                            top.pendingValueStart = top.pendingValueStart ?? top.openOffset
                        }
                        stack.append(top)
                    }
                }
                i += 1
                continue
            }

            switch byte {
            case 0x20, 0x09, 0x0A, 0x0D: // whitespace
                i += 1
            case 0x22: // string opens
                inString = true
                if var top = stack.popLast() {
                    if top.kind == .object, top.lastColonOffset == nil, top.pendingKeyStart == nil {
                        top.pendingKeyStart = i
                    } else {
                        top.pendingValueStart = top.pendingValueStart ?? i
                    }
                    stack.append(top)
                }
                i += 1
            case 0x7B: // {
                if var parent = stack.popLast() {
                    parent.pendingValueStart = parent.pendingValueStart ?? i
                    stack.append(parent)
                }
                stack.append(ContainerFrame(
                    kind: .object,
                    openOffset: i,
                    lastCommaOffset: nil,
                    lastColonOffset: nil,
                    pendingKeyStart: nil,
                    pendingValueStart: nil
                ))
                i += 1
            case 0x5B: // [
                if var parent = stack.popLast() {
                    parent.pendingValueStart = parent.pendingValueStart ?? i
                    stack.append(parent)
                }
                stack.append(ContainerFrame(
                    kind: .array,
                    openOffset: i,
                    lastCommaOffset: nil,
                    lastColonOffset: nil,
                    pendingKeyStart: nil,
                    pendingValueStart: nil
                ))
                i += 1
            case 0x7D: // }
                guard let top = stack.popLast() else {
                    throw RepairError(reason: "unmatched closing '}'")
                }
                guard top.kind == .object else {
                    throw RepairError(reason: "mismatched closer: '}' for array")
                }
                i += 1
            case 0x5D: // ]
                guard let top = stack.popLast() else {
                    throw RepairError(reason: "unmatched closing ']'")
                }
                guard top.kind == .array else {
                    throw RepairError(reason: "mismatched closer: ']' for object")
                }
                i += 1
            case 0x3A: // :
                if var top = stack.popLast() {
                    top.lastColonOffset = i
                    stack.append(top)
                }
                i += 1
            case 0x2C: // ,
                if var top = stack.popLast() {
                    top.lastCommaOffset = i
                    top.pendingKeyStart = nil
                    top.pendingValueStart = nil
                    top.lastColonOffset = nil
                    stack.append(top)
                }
                i += 1
            default:
                // A literal value (number, true, false, null) — record it as
                // the pending value start for the current frame.
                if var top = stack.popLast() {
                    if top.kind == .object, top.lastColonOffset == nil, top.pendingKeyStart == nil {
                        // Numbers/literals as keys are illegal — flag.
                        throw RepairError(reason: "non-string key in object")
                    }
                    if top.pendingValueStart == nil {
                        top.pendingValueStart = i
                    }
                    stack.append(top)
                }
                i += 1
            }
        }

        return ScanState(truncated: trimmed, containerStack: stack, inString: inString)
    }
}

// MARK: - Trimming helpers

private func trimDanglingFragment(
    in raw: String,
    frame: ContainerFrame,
    scratch: inout [String]
) -> String {
    var output = raw
    let bytes = Array(output.utf8)

    switch frame.kind {
    case .object:
        // If we have a pending key without a colon, or a colon without a
        // value, drop everything from the last separator (comma or open
        // brace) onwards.
        let needsCut: Bool
        if frame.pendingKeyStart != nil, frame.lastColonOffset == nil {
            needsCut = true
        } else if let colon = frame.lastColonOffset,
                  frame.pendingValueStart == nil || (frame.pendingValueStart ?? 0) <= colon {
            // Colon consumed but no value started, or "value" is just the colon.
            needsCut = true
        } else if frame.pendingValueStart != nil, !valueLooksComplete(bytes: bytes, from: frame.pendingValueStart!) {
            // Value started but unfinished literal/number.
            return trimPartialLiteral(output: output, frame: frame, scratch: &scratch)
        } else {
            needsCut = false
        }

        if needsCut {
            let cutPoint = frame.lastCommaOffset ?? frame.openOffset
            // Drop everything from cutPoint forward — keep cutPoint byte itself
            // when it's the open brace; drop the comma when it's a comma.
            let keepThrough: Int = if let comma = frame.lastCommaOffset, cutPoint == comma {
                comma // exclusive
            } else {
                frame.openOffset + 1 // keep the '{'
            }
            output = String(bytes: bytes.prefix(keepThrough), encoding: .utf8) ?? output
            scratch.append("dropped dangling object fragment")
        } else {
            // Drop trailing comma immediately before EOF, if any.
            if let comma = frame.lastCommaOffset,
               trailingNonWhitespaceByte(bytes) == 0x2C,
               comma == lastIndex(of: 0x2C, in: bytes) {
                output = String(bytes: bytes.prefix(comma), encoding: .utf8) ?? output
                scratch.append("dropped trailing comma")
            }
        }

    case .array:
        if let valueStart = frame.pendingValueStart, !valueLooksComplete(bytes: bytes, from: valueStart) {
            return trimPartialLiteral(output: output, frame: frame, scratch: &scratch)
        }
        // Drop trailing comma.
        if let comma = frame.lastCommaOffset,
           trailingNonWhitespaceByte(bytes) == 0x2C,
           comma == lastIndex(of: 0x2C, in: bytes) {
            output = String(bytes: bytes.prefix(comma), encoding: .utf8) ?? output
            scratch.append("dropped trailing comma")
        }
    }

    return output
}

/// True iff the substring starting at `from` parses as a complete value
/// (string already-handled, number/literal terminating at EOF).
private func valueLooksComplete(bytes: [UInt8], from: Int) -> Bool {
    guard from < bytes.count else { return false }
    let firstByte = bytes[from]
    switch firstByte {
    case 0x22: // string — closed already by scanner if we reached here
        return true
    case 0x7B, 0x5B: // object/array — closed by stack pop, not by us
        return true
    case 0x74: // 't' for true
        return matchesLiteral(bytes: bytes, from: from, literal: [0x74, 0x72, 0x75, 0x65])
    case 0x66: // 'f' for false
        return matchesLiteral(bytes: bytes, from: from, literal: [0x66, 0x61, 0x6C, 0x73, 0x65])
    case 0x6E: // 'n' for null
        return matchesLiteral(bytes: bytes, from: from, literal: [0x6E, 0x75, 0x6C, 0x6C])
    default:
        // Number — accept if it matches the digit/sign/dot/exponent pattern
        // through the end of the buffer.
        return isCompleteNumber(bytes: bytes, from: from)
    }
}

private func matchesLiteral(bytes: [UInt8], from: Int, literal: [UInt8]) -> Bool {
    guard bytes.count - from >= literal.count else { return false }
    for offset in 0 ..< literal.count where bytes[from + offset] != literal[offset] {
        return false
    }
    let endIndex = from + literal.count
    if endIndex == bytes.count { return true }
    let next = bytes[endIndex]
    return next == 0x2C || next == 0x7D || next == 0x5D || isWhitespace(next)
}

private func isCompleteNumber(bytes: [UInt8], from: Int) -> Bool {
    var i = from
    if i < bytes.count, bytes[i] == 0x2D { i += 1 }
    var sawDigit = false
    while i < bytes.count, isDigit(bytes[i]) {
        sawDigit = true
        i += 1
    }
    if i < bytes.count, bytes[i] == 0x2E {
        i += 1
        var sawFrac = false
        while i < bytes.count, isDigit(bytes[i]) {
            sawFrac = true
            i += 1
        }
        if !sawFrac { return false }
    }
    if i < bytes.count, bytes[i] == 0x65 || bytes[i] == 0x45 {
        i += 1
        if i < bytes.count, bytes[i] == 0x2B || bytes[i] == 0x2D { i += 1 }
        var sawExp = false
        while i < bytes.count, isDigit(bytes[i]) {
            sawExp = true
            i += 1
        }
        if !sawExp { return false }
    }
    return sawDigit && i == bytes.count
}

private func trimPartialLiteral(
    output: String,
    frame: ContainerFrame,
    scratch: inout [String]
) -> String {
    let bytes = Array(output.utf8)
    let cutPoint: Int = if let valueStart = frame.pendingValueStart {
        if let comma = frame.lastCommaOffset, comma < valueStart {
            comma
        } else if frame.kind == .object, let colon = frame.lastColonOffset, colon < valueStart {
            // Drop the dangling key/colon/value triple back to the previous
            // separator (comma or open brace).
            frame.lastCommaOffset ?? frame.openOffset
        } else {
            frame.openOffset + 1
        }
    } else {
        frame.openOffset + 1
    }
    let keepThrough = (cutPoint == frame.openOffset) ? (frame.openOffset + 1) : cutPoint
    scratch.append("dropped partial literal/number")
    return String(bytes: bytes.prefix(keepThrough), encoding: .utf8) ?? output
}

private func trailingNonWhitespaceByte(_ bytes: [UInt8]) -> UInt8? {
    var i = bytes.count - 1
    while i >= 0 {
        if !isWhitespace(bytes[i]) { return bytes[i] }
        i -= 1
    }
    return nil
}

private func lastIndex(of byte: UInt8, in bytes: [UInt8]) -> Int? {
    var i = bytes.count - 1
    while i >= 0 {
        if bytes[i] == byte { return i }
        i -= 1
    }
    return nil
}

private func isWhitespace(_ byte: UInt8) -> Bool {
    byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D
}

private func isDigit(_ byte: UInt8) -> Bool {
    byte >= 0x30 && byte <= 0x39
}

// MARK: - Unicode escape back-off

/// If `raw` ends with a partial `\uXXXX` escape (1–4 hex digits short of a
/// full escape), trim the partial sequence so closing the string is safe.
private func backOffPartialUnicodeEscape(_ raw: String) -> String? {
    let bytes = Array(raw.utf8)
    // Walk back up to 5 bytes looking for a `\u` that hasn't completed.
    let maxBackoff = min(bytes.count, 5)
    for offset in 1 ... maxBackoff {
        let i = bytes.count - offset
        if i < 0 { break }
        if bytes[i] == 0x75 /* 'u' */, i >= 1, bytes[i - 1] == 0x5C /* '\' */ {
            // Have we seen 4 hex digits after the 'u'? bytes after `i` (the 'u')
            // are at i+1 .. bytes.count-1. We need exactly 4.
            let hexCount = bytes.count - (i + 1)
            if hexCount < 4 {
                let trimTo = i - 1 // drop the backslash too
                return String(bytes: bytes.prefix(trimTo), encoding: .utf8)
            }
            return nil
        }
    }
    return nil
}

private func endsInDanglingBackslash(_ raw: String) -> Bool {
    // Count the run of trailing backslashes; odd → dangling.
    let bytes = Array(raw.utf8)
    var count = 0
    var i = bytes.count - 1
    while i >= 0, bytes[i] == 0x5C {
        count += 1
        i -= 1
    }
    return count % 2 == 1
}
