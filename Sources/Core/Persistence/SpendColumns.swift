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

        CREATE TABLE IF NOT EXISTS usage_days (
            file TEXT NOT NULL,
            day REAL NOT NULL,
            model TEXT NOT NULL,
            directory TEXT NOT NULL,
            provider TEXT NOT NULL,
            agent_session_id TEXT NOT NULL,
            fresh_input INTEGER NOT NULL DEFAULT 0,
            cache_read INTEGER NOT NULL DEFAULT 0,
            cache_write_short INTEGER NOT NULL DEFAULT 0,
            cache_write_long INTEGER NOT NULL DEFAULT 0,
            output INTEGER NOT NULL DEFAULT 0,
            turns INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (file, day, model, directory)
        );
        CREATE INDEX IF NOT EXISTS usage_days_day ON usage_days(day);
        """

    static let add = """
        INSERT INTO usage_days (
            file, day, model, directory, provider, agent_session_id,
            fresh_input, cache_read, cache_write_short, cache_write_long, output, turns
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT (file, day, model, directory) DO UPDATE SET
            fresh_input = fresh_input + excluded.fresh_input,
            cache_read = cache_read + excluded.cache_read,
            cache_write_short = cache_write_short + excluded.cache_write_short,
            cache_write_long = cache_write_long + excluded.cache_write_long,
            output = output + excluded.output,
            turns = turns + excluded.turns,
            agent_session_id = excluded.agent_session_id,
            provider = excluded.provider
        """

    static let forget = "DELETE FROM usage_days WHERE file = ?"

    static let since = "SELECT * FROM usage_days WHERE day >= ? ORDER BY day"

    static let rememberFile = """
        INSERT INTO usage_files (
            path, provider, size, modified_at, read_offset, carried_model, carried_directory, read_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT (path) DO UPDATE SET
            provider = excluded.provider,
            size = excluded.size,
            modified_at = excluded.modified_at,
            read_offset = excluded.read_offset,
            carried_model = excluded.carried_model,
            carried_directory = excluded.carried_directory,
            read_at = excluded.read_at
        """

    static func values(_ day: SpendDay) -> [SQLValue] {
        [
            .text(day.file),
            .double(day.day.timeIntervalSince1970),
            .text(day.model),
            .text(day.directory),
            .text(day.provider.rawValue),
            .text(day.agentSessionID),
            .int(Int64(day.usage.freshInput)),
            .int(Int64(day.usage.cacheRead)),
            .int(Int64(day.usage.cacheWriteShort)),
            .int(Int64(day.usage.cacheWriteLong)),
            .int(Int64(day.usage.output)),
            .int(Int64(day.turns)),
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
            agentSessionID: row.string("agent_session_id") ?? "",
            file: row.string("file") ?? "",
            usage: TokenUsage(
                freshInput: Int(row.int("fresh_input") ?? 0),
                cacheRead: Int(row.int("cache_read") ?? 0),
                cacheWriteShort: Int(row.int("cache_write_short") ?? 0),
                cacheWriteLong: Int(row.int("cache_write_long") ?? 0),
                output: Int(row.int("output") ?? 0)
            ),
            turns: Int(row.int("turns") ?? 0)
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
