import Foundation

public enum InspectorTab: String, Hashable, CaseIterable, Sendable {
    case allFiles = "All files"
    case changes = "Changes"
    case tasks = "Tasks"
    case checks = "Checks"

    public var symbol: String {
        switch self {
        case .allFiles: "list.bullet"
        case .changes: "plus.forwardslash.minus"
        case .tasks: "checklist"
        case .checks: "checkmark.circle"
        }
    }

    public static let fallback: InspectorTab = .changes

    public static func available(for pullRequest: PullRequest?, hasTasks: Bool = false) -> [InspectorTab] {
        allCases.filter { tab in
            switch tab {
            case .allFiles, .changes: true
            case .tasks: hasTasks
            case .checks: hasChecks(pullRequest)
            }
        }
    }

    public var readsTheDiff: Bool { self == .allFiles || self == .changes }

    public static func hasChecks(_ pullRequest: PullRequest?) -> Bool {
        guard let pullRequest else { return false }
        return pullRequest.checks != .none
    }

    public static func resolve(_ selected: InspectorTab, available: [InspectorTab]) -> InspectorTab {
        if available.contains(selected) { return selected }
        return available.contains(fallback) ? fallback : (available.first ?? fallback)
    }
}
