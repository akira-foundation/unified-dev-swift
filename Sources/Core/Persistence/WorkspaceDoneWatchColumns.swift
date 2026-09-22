import Foundation

enum WorkspaceDoneWatchColumns {
    static func migrate(_ db: SQLiteDatabase) throws {
        let columns = Set(try db.query("PRAGMA table_info(workspace_messages);").compactMap { $0.string("name") })
        if !columns.contains("notify_when_done") {
            try db.execute("ALTER TABLE workspace_messages ADD COLUMN notify_when_done INTEGER NOT NULL DEFAULT 0;")
        }
        try db.execute(createTable)
    }

    static let createTable = """
        CREATE TABLE IF NOT EXISTS workspace_done_watches (
            id TEXT PRIMARY KEY,
            message_id TEXT,
            watcher_session_id TEXT NOT NULL,
            target_workspace_id TEXT NOT NULL,
            target_workspace_name TEXT NOT NULL DEFAULT '',
            target_project_name TEXT NOT NULL DEFAULT '',
            target_session_id TEXT,
            target_chat TEXT NOT NULL DEFAULT '',
            created_at REAL NOT NULL,
            notified_at REAL
        );
        CREATE INDEX IF NOT EXISTS workspace_done_watches_target
            ON workspace_done_watches(target_workspace_id, notified_at);
        """

    static let insert = """
        INSERT INTO workspace_done_watches
            (id, message_id, watcher_session_id, target_workspace_id, target_workspace_name,
             target_project_name, target_session_id, target_chat, created_at, notified_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
        """

    private static let withMessageState = """
        SELECT w.*, m.state AS message_state FROM workspace_done_watches w
        LEFT JOIN workspace_messages m ON m.id = w.message_id
        """

    static let unspentForTarget = """
        \(withMessageState)
        WHERE w.target_workspace_id = ? AND w.notified_at IS NULL
        ORDER BY w.created_at, w.rowid
        """

    static let byID = "\(withMessageState) WHERE w.id = ?"

    static let claim = "UPDATE workspace_done_watches SET notified_at = ? WHERE id = ? AND notified_at IS NULL"

    static func values(_ watch: WorkspaceDoneWatch) -> [SQLValue] {
        let messageID: SQLValue = if case .message(let id, _) = watch.cause { .text(id) } else { .null }
        return [
            .text(watch.id),
            messageID,
            .text(watch.watcherSessionID),
            .text(watch.target.workspaceID),
            .text(watch.target.workspace),
            .text(watch.target.project),
            .text(watch.target.sessionID),
            .text(watch.target.chat),
            .double(watch.createdAt.timeIntervalSince1970),
        ]
    }

    static func watch(from row: Row) -> WorkspaceDoneWatch {
        let cause: WorkspaceDoneWatch.Cause = if let messageID = row.string("message_id") {
            .message(
                WorkspaceMessageID(messageID),
                state: WorkspaceMessage.State(rawValue: row.string("message_state") ?? "") ?? .cancelled
            )
        } else {
            .start
        }
        return WorkspaceDoneWatch(
            id: WorkspaceDoneWatchID(row.string("id") ?? newID()),
            cause: cause,
            watcherSessionID: SessionID(row.string("watcher_session_id") ?? ""),
            target: WorkspaceMessageEnd(
                workspaceID: row.string("target_workspace_id").map(WorkspaceID.init),
                workspace: row.string("target_workspace_name") ?? "",
                project: row.string("target_project_name") ?? "",
                sessionID: row.string("target_session_id").map(SessionID.init),
                chat: row.string("target_chat") ?? ""
            ),
            createdAt: row.date("created_at") ?? Date(),
            notifiedAt: row.date("notified_at")
        )
    }

    static func messageWatch(_ message: WorkspaceMessage, into chat: Session) -> WorkspaceDoneWatch? {
        guard message.notifyWhenDone, let watcher = message.source.sessionID,
              let targetWorkspaceID = message.target.workspaceID
        else { return nil }
        return WorkspaceDoneWatch(
            cause: .message(message.id, state: .queued),
            watcherSessionID: watcher,
            target: WorkspaceMessageEnd(
                workspaceID: targetWorkspaceID,
                workspace: message.target.workspace,
                project: message.target.project,
                sessionID: chat.id,
                chat: chat.title
            ),
            createdAt: message.createdAt
        )
    }
}
