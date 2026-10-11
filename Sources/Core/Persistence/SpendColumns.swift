import Foundation

enum SpendColumns {
    static let createTables = """
        CREATE TABLE IF NOT EXISTS usage_files (
            path TEXT PRIMARY KEY,
            provider TEXT NOT NULL,
            size INTEGER NOT NULL,
            modified_at REAL NOT NULL,
            read_offset INTEGER NOT NULL DEFAULT 0,
            carried_model TEXT NOT NULL DEFAULT '',
            carried_directory TEXT NOT NULL DEFAULT '',
            read_at REAL NOT NULL
        );

        CREATE TABLE IF NOT EXISTS usage_turns (
            file TEXT NOT NULL,
            turn_key TEXT NOT NULL,
            day REAL NOT NULL,
            model TEXT NOT NULL,
            directory TEXT NOT NULL,
            provider TEXT NOT NULL,
            price_tier INTEGER NOT NULL DEFAULT 0,
            fresh_input INTEGER NOT NULL DEFAULT 0,
            cache_read INTEGER NOT NULL DEFAULT 0,
            cache_write_short INTEGER NOT NULL DEFAULT 0,
            cache_write_long INTEGER NOT NULL DEFAULT 0,
            output INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (file, turn_key)
        );
        CREATE INDEX IF NOT EXISTS usage_turns_day ON usage_turns(day);
        """

    static let add = """
        INSERT OR IGNORE INTO usage_turns (
            file, turn_key, day, model, directory, provider, price_tier,
            fresh_input, cache_read, cache_write_short, cache_write_long, output
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

    static let forget = "DELETE FROM usage_turns WHERE file = ?"

    static let since = """
        SELECT file, day, model, directory, provider, price_tier,
            SUM(fresh_input) AS fresh_input,
            SUM(cache_read) AS cache_read,
            SUM(cache_write_short) AS cache_write_short,
            SUM(cache_write_long) AS cache_write_long,
            SUM(output) AS output,
            COUNT(*) AS turns
        FROM usage_turns
        WHERE day >= ?
        GROUP BY file, day, model, directory, provider, price_tier
        ORDER BY day
        """

    static let rememberFile = """
        INSERT INTO usage_files (
            path, provider, size, modified_at, read_offset, carried_model, carried_directory, read_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT (path) DO UPDATE SET
            size = excluded.size,
            modified_at = excluded.modified_at,
            read_offset = excluded.read_offset,
            carried_model = excluded.carried_model,
            carried_directory = excluded.carried_directory,
            read_at = excluded.read_at
        """

    static func values(_ turn: SpendTurn) -> [SQLValue] {
        [
            .text(turn.file),
            .text(turn.key),
            .double(turn.day.timeIntervalSince1970),
            .text(turn.model),
            .text(turn.directory),
            .text(turn.provider.rawValue),
            .int(Int64(turn.tier.rawValue)),
            .int(Int64(turn.usage.freshInput)),
            .int(Int64(turn.usage.cacheRead)),
            .int(Int64(turn.usage.cacheWriteShort)),
            .int(Int64(turn.usage.cacheWriteLong)),
            .int(Int64(turn.usage.output)),
        ]
    }

    static func values(_ cursor: TranscriptCursor, at date: Date) -> [SQLValue] {
        [
            .text(cursor.path),
            .text(cursor.provider.rawValue),
            .int(Int64(cursor.size)),
            .double(cursor.modifiedAt.timeIntervalSince1970),
            .int(Int64(cursor.offset)),
            .text(cursor.carry.model),
            .text(cursor.carry.directory),
            .double(date.timeIntervalSince1970),
        ]
    }

    static func day(from row: Row) -> SpendDay {
        SpendDay(
            provider: AgentKind(rawValue: row.string("provider") ?? "") ?? .claudeCode,
            day: row.date("day") ?? Date(timeIntervalSince1970: 0),
            model: row.string("model") ?? "",
            directory: row.string("directory") ?? "",
            file: row.string("file") ?? "",
            usage: TokenUsage(
                freshInput: Int(row.int("fresh_input") ?? 0),
                cacheRead: Int(row.int("cache_read") ?? 0),
                cacheWriteShort: Int(row.int("cache_write_short") ?? 0),
                cacheWriteLong: Int(row.int("cache_write_long") ?? 0),
                output: Int(row.int("output") ?? 0)
            ),
            turns: Int(row.int("turns") ?? 0),
            tier: PriceTier(rawValue: Int(row.int("price_tier") ?? 0)) ?? .base
        )
    }

    static func cursor(from row: Row) -> TranscriptCursor {
        TranscriptCursor(
            path: row.string("path") ?? "",
            provider: AgentKind(rawValue: row.string("provider") ?? "") ?? .claudeCode,
            size: Int(row.int("size") ?? 0),
            modifiedAt: row.date("modified_at") ?? Date(timeIntervalSince1970: 0),
            offset: Int(row.int("read_offset") ?? 0),
            carry: TranscriptCarry(
                model: row.string("carried_model") ?? "",
                directory: row.string("carried_directory") ?? ""
            )
        )
    }
}
