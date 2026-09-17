import Foundation

public enum BridgeWorkspaceLookup: Sendable {
    public enum Outcome: Sendable, Equatable {
        case found(Workspace)
        case unknown
        case ambiguous([Workspace])
    }

    public static func find(_ query: String, among workspaces: [Workspace]) -> Outcome {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .unknown }

        if let byID = workspaces.first(where: {
            $0.id.rawValue.caseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            return .found(byID)
        }

        let byName = workspaces.filter { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }
        switch byName.count {
        case 0: return .unknown
        case 1: return .found(byName[0])
        default: return .ambiguous(byName)
        }
    }

    static let listLimit = 10

    static func list(_ names: [String]) -> String {
        guard !names.isEmpty else { return "nothing" }
        let shown = names.prefix(listLimit).joined(separator: ", ")
        let rest = names.count - listLimit
        return rest > 0 ? shown + " and \(rest) more" : shown
    }
}
