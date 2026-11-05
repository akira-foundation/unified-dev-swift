import Foundation

enum ReplyQuoteColumns {
    static let createTable = """
        CREATE TABLE IF NOT EXISTS reply_quotes (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
            quoted TEXT NOT NULL,
            summary TEXT NOT NULL,
            source_seq INTEGER
        );
        CREATE INDEX IF NOT EXISTS reply_quotes_session ON reply_quotes(session_id);
        """

    static func quote(from row: Row) -> ReplyQuote? {
        guard let id = row.string("id"), let quoted = row.string("quoted"),
              let summary = row.string("summary") else { return nil }
        return ReplyQuote(
            id: ReplyQuoteID(id), quoted: quoted, summary: summary, sourceSeq: row.int("source_seq").map(Int.init)
        )
    }
}
