import Foundation

public enum AskTabs {
    public static let selectionKey = "ask.selectedSession"

    public static func directoryKey(_ id: SessionID) -> String { "ask.directory.\(id.rawValue)" }

    public static func selection(saved: String?, sessions: [Session]) -> SessionID? {
        sessions.first { $0.id.rawValue == saved }?.id ?? sessions.first?.id
    }

    public static func selectionAfterClosing(
        _ id: SessionID, selected: SessionID?, sessions: [Session]
    ) -> SessionID? {
        let ids = sessions.map(\.id)
        let current = selected.flatMap { ids.contains($0) ? $0 : nil } ?? id
        return TabClosure.selectionAfterClosing(id, selected: current, tabs: ids)
    }

    public static func prepareDirectory(_ path: String, databasePath: String) -> String? {
        if path.isEmpty { return AskConversation.prepareDirectory(besideDatabaseAt: databasePath) }
        let expanded = NewProjectPlan.expand(path, home: FileManager.default.homeDirectoryForCurrentUser.path)
        var isDirectory: ObjCBool = false
        guard expanded.hasPrefix("/"),
              FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory),
              isDirectory.boolValue else { return nil }
        return FolderPath.normalize(expanded)
    }
}
