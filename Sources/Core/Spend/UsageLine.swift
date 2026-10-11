import Foundation

public enum UsageLine {
    static let usageKey = "usage"
    static let directoryKey = "cwd"

    public static func mayHoldUsage(
        in bytes: UnsafeBufferPointer<UInt8>,
        from start: Int,
        to end: Int,
        provider: AgentKind
    ) -> Bool {
        switch provider {
        case .claudeCode:
            holds(usageKey, in: bytes, from: start, to: end)
        case .codex:
            holds(usageKey, in: bytes, from: start, to: end)
                || holds(directoryKey, in: bytes, from: start, to: end)
        case .grok, .cursor, .openCode:
            false
        }
    }

    static func holds(
        _ needle: String,
        in bytes: UnsafeBufferPointer<UInt8>,
        from start: Int,
        to end: Int
    ) -> Bool {
        guard let base = bytes.baseAddress, end > start else { return false }
        var needleBytes = [UInt8](needle.utf8)
        guard needleBytes.count <= end - start else { return false }
        return needleBytes.withUnsafeBufferPointer { pattern in
            guard let patternBase = pattern.baseAddress else { return false }
            return memmem(base + start, end - start, patternBase, pattern.count) != nil
        }
    }

    public static func record(
        in bytes: UnsafeBufferPointer<UInt8>,
        from start: Int,
        to end: Int,
        provider: AgentKind,
        carry: inout TranscriptCarry
    ) -> SpendRecord? {
        guard mayHoldUsage(in: bytes, from: start, to: end, provider: provider) else { return nil }
        return switch provider {
        case .claudeCode:
            ClaudeUsageLine.record(in: bytes, from: start, to: end)
        case .codex:
            CodexUsageLine.record(in: bytes, from: start, to: end, carry: &carry)
        case .grok, .cursor, .openCode:
            nil
        }
    }

    public static func record(
        inLine line: String,
        provider: AgentKind,
        carry: inout TranscriptCarry
    ) -> SpendRecord? {
        let bytes = [UInt8](line.utf8)
        var carried = carry
        let record = bytes.withUnsafeBufferPointer { buffer in
            UsageLine.record(
                in: buffer, from: 0, to: buffer.count, provider: provider, carry: &carried
            )
        }
        carry = carried
        return record
    }
}
