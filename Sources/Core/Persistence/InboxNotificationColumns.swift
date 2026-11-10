import Foundation

enum InboxNotificationColumns {
    static let createTable = """
        CREATE TABLE IF NOT EXISTS inbox_notifications (
            id TEXT PRIMARY KEY,
            event TEXT NOT NULL,
            workspace_id TEXT NOT NULL,
            session_id TEXT,
            workspace_name TEXT NOT NULL,
            detail TEXT NOT NULL DEFAULT '',
            profile_id TEXT,
            created_at REAL NOT NULL,
            read_at REAL
        );
        CREATE INDEX IF NOT EXISTS inbox_notifications_workspace
            ON inbox_notifications(workspace_id, read_at);
        """
}
