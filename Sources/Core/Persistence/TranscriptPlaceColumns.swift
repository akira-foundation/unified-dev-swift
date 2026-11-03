import Foundation

enum TranscriptPlaceColumns {
    static let createTable = """
        CREATE TABLE IF NOT EXISTS transcript_places (
            session_id TEXT PRIMARY KEY REFERENCES sessions(id) ON DELETE CASCADE,
            anchor_seq INTEGER NOT NULL,
            anchor_delta REAL NOT NULL,
            is_at_live_end INTEGER NOT NULL,
            row_count INTEGER NOT NULL
        );
        """
}
