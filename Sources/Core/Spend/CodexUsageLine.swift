import Foundation

enum CodexUsageLine {
    static func record(
        in bytes: UnsafeBufferPointer<UInt8>,
        from start: Int,
        to end: Int,
        carry: inout TranscriptCarry
    ) -> SpendRecord? {
        var cursor = JSONCursor(bytes, from: start, to: end)
        guard cursor.enterObject() else { return nil }

        var stamp: String?
        var directory: String?
        var model: String?
        var identity = ""
        var usage: TokenUsage?

        while let key = cursor.nextKey() {
            if cursor.matches(key, "timestamp") {
                stamp = cursor.text()
                continue
            }
            if cursor.matches(key, "ordinal") {
                identity = cursor.integer().map(String.init) ?? ""
                continue
            }
            if cursor.matches(key, "payload") {
                readPayload(&cursor, directory: &directory, model: &model, usage: &usage)
                continue
            }
            cursor.skipValue()
        }

        if let directory, !directory.isEmpty { carry.directory = directory }
        if let model, !model.isEmpty { carry.model = model }

        guard cursor.closedObject else { return nil }
        guard let usage, !usage.isEmpty, let stamp, let happenedAt = TranscriptTimestamp.date(from: stamp)
        else { return nil }

        return SpendRecord(
            provider: .codex,
            happenedAt: happenedAt,
            model: carry.model,
            directory: carry.directory,
            key: identity,
            usage: usage
        )
    }

    private static func readPayload(
        _ cursor: inout JSONCursor,
        directory: inout String?,
        model: inout String?,
        usage: inout TokenUsage?
    ) {
        guard cursor.enterObject() else {
            cursor.skipValue()
            return
        }
        while let key = cursor.nextKey() {
            if cursor.matches(key, "cwd") {
                directory = cursor.text()
                continue
            }
            if cursor.matches(key, "model") {
                model = cursor.text()
                continue
            }
            if cursor.matches(key, "info") {
                usage = readInfo(&cursor)
                continue
            }
            cursor.skipValue()
        }
    }

    private static func readInfo(_ cursor: inout JSONCursor) -> TokenUsage? {
        guard cursor.enterObject() else {
            cursor.skipValue()
            return nil
        }
        var usage: TokenUsage?
        while let key = cursor.nextKey() {
            if cursor.matches(key, "last_token_usage") {
                usage = readTurn(&cursor)
                continue
            }
            cursor.skipValue()
        }
        return usage
    }

    private static func readTurn(_ cursor: inout JSONCursor) -> TokenUsage? {
        guard cursor.enterObject() else {
            cursor.skipValue()
            return nil
        }
        var input = 0
        var cached = 0
        var usage = TokenUsage()
        while let key = cursor.nextKey() {
            if cursor.matches(key, "input_tokens") {
                input = cursor.integer() ?? 0
                continue
            }
            if cursor.matches(key, "cached_input_tokens") {
                cached = cursor.integer() ?? 0
                continue
            }
            if cursor.matches(key, "cache_write_input_tokens") {
                usage.cacheWriteShort = cursor.integer() ?? 0
                continue
            }
            if cursor.matches(key, "output_tokens") {
                usage.output = cursor.integer() ?? 0
                continue
            }
            cursor.skipValue()
        }
        usage.cacheRead = min(cached, input)
        usage.freshInput = max(0, input - usage.cacheRead)
        return usage
    }
}
