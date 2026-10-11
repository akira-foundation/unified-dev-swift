import Foundation

enum ClaudeUsageLine {
    static func record(
        in bytes: UnsafeBufferPointer<UInt8>,
        from start: Int,
        to end: Int
    ) -> SpendRecord? {
        var cursor = JSONCursor(bytes, from: start, to: end)
        guard cursor.enterObject() else { return nil }

        var stamp: String?
        var directory = ""
        var model = ""
        var identity = ""
        var usage: TokenUsage?

        while let key = cursor.nextKey() {
            if cursor.matches(key, "timestamp") {
                stamp = cursor.text()
                continue
            }
            if cursor.matches(key, "cwd") {
                directory = cursor.text() ?? ""
                continue
            }
            if cursor.matches(key, "message") {
                readMessage(&cursor, model: &model, identity: &identity, usage: &usage)
                continue
            }
            cursor.skipValue()
        }

        guard cursor.closedObject else { return nil }
        guard let usage, !usage.isEmpty, let stamp, let happenedAt = TranscriptTimestamp.date(from: stamp)
        else { return nil }

        return SpendRecord(
            provider: .claudeCode,
            happenedAt: happenedAt,
            model: model,
            directory: directory,
            key: identity,
            usage: usage
        )
    }

    private static func readMessage(
        _ cursor: inout JSONCursor,
        model: inout String,
        identity: inout String,
        usage: inout TokenUsage?
    ) {
        guard cursor.enterObject() else {
            cursor.skipValue()
            return
        }
        while let key = cursor.nextKey() {
            if cursor.matches(key, "model") {
                model = cursor.text() ?? ""
                continue
            }
            if cursor.matches(key, "id") {
                identity = cursor.text() ?? ""
                continue
            }
            if cursor.matches(key, "usage") {
                usage = readUsage(&cursor)
                continue
            }
            cursor.skipValue()
        }
    }

    private static func readUsage(_ cursor: inout JSONCursor) -> TokenUsage? {
        guard cursor.enterObject() else {
            cursor.skipValue()
            return nil
        }
        var usage = TokenUsage()
        var sawCreationBreakdown = false
        var creationTotal = 0

        while let key = cursor.nextKey() {
            if cursor.matches(key, "input_tokens") {
                usage.freshInput = cursor.integer() ?? 0
                continue
            }
            if cursor.matches(key, "output_tokens") {
                usage.output = cursor.integer() ?? 0
                continue
            }
            if cursor.matches(key, "cache_read_input_tokens") {
                usage.cacheRead = cursor.integer() ?? 0
                continue
            }
            if cursor.matches(key, "cache_creation_input_tokens") {
                creationTotal = cursor.integer() ?? 0
                continue
            }
            if cursor.matches(key, "cache_creation") {
                readCreation(&cursor, into: &usage, sawBreakdown: &sawCreationBreakdown)
                continue
            }
            cursor.skipValue()
        }

        if !sawCreationBreakdown { usage.cacheWriteShort = creationTotal }
        return usage
    }

    private static func readCreation(
        _ cursor: inout JSONCursor,
        into usage: inout TokenUsage,
        sawBreakdown: inout Bool
    ) {
        guard cursor.enterObject() else {
            cursor.skipValue()
            return
        }
        while let key = cursor.nextKey() {
            if cursor.matches(key, "ephemeral_5m_input_tokens") {
                usage.cacheWriteShort = cursor.integer() ?? 0
                sawBreakdown = true
                continue
            }
            if cursor.matches(key, "ephemeral_1h_input_tokens") {
                usage.cacheWriteLong = cursor.integer() ?? 0
                sawBreakdown = true
                continue
            }
            cursor.skipValue()
        }
    }
}
