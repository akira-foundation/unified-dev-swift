import Foundation

public enum WorkspaceSayThrottle {
    public static let limit = 30
    public static let window: TimeInterval = 10 * 60

    static var windowMinutes: Int { Int(window / 60) }

    public static func refusal(
        sending text: String, to workspace: String, recent: [WorkspaceMessage], now: Date = Date()
    ) -> WorkspaceSayTrouble? {
        let since = now.addingTimeInterval(-window)
        let counted = recent.filter { $0.state != .cancelled && $0.createdAt >= since }
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if counted.contains(where: { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) == words }) {
            return .repeated(workspace: workspace)
        }
        if counted.count >= limit {
            return .tooMany(workspace: workspace, count: counted.count)
        }
        return nil
    }
}
