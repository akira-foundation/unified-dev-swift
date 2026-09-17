import Foundation

public enum SearchPanelSummary {
    public static func searching(scope: HomeScope, counts: HomeScopeCounts) -> String? {
        let count = counts.count(of: scope, searching: true)
        guard count > 0 else { return nil }
        switch scope {
        case .workspaces:
            return count == 1 ? "1 workspace" : "\(count) workspaces"
        case .transcripts:
            return count == 1 ? "1 match" : "\(count) matches"
        default:
            return rows(count)
        }
    }

    public static func resting(shown: Int, of total: Int) -> String? {
        guard shown > 0 else { return nil }
        guard total > shown else {
            return shown == 1 ? "1 workspace" : "\(shown) workspaces"
        }
        return "\(shown) of \(total) workspaces"
    }

    public static func rows(_ count: Int) -> String? {
        guard count > 0 else { return nil }
        return count == 1 ? "1 result" : "\(count) results"
    }
}
