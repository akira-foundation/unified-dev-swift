import Foundation

public enum ReviewDestination {
    public static func resolved(
        chosen: SessionID?,
        active: SessionID?,
        sessions: [SessionID]
    ) -> SessionID? {
        if let chosen, sessions.contains(chosen) { return chosen }
        if let active, sessions.contains(active) { return active }
        return sessions.first
    }

    public static func isChoosable(sessions: [SessionID]) -> Bool {
        sessions.count > 1
    }

    public static func label(for title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return "Messages are sent to \(trimmed.isEmpty ? "Chat" : trimmed)"
    }
}
