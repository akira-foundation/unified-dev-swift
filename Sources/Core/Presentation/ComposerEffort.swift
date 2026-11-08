import Foundation

public enum ComposerEffort {
    public static let unsetID = ""
    public static let unsetLabel = "Agent default"

    public static func isUnset(_ id: String) -> Bool {
        id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public static func choices(
        _ supported: [AgentModelEffort],
        offeringUnset: Bool
    ) -> [AgentModelEffort] {
        guard offeringUnset, !supported.contains(where: { isUnset($0.id) }) else { return supported }
        return [AgentModelEffort(id: unsetID, label: unsetLabel)] + supported
    }

    public static func label(for id: String, among choices: [AgentModelEffort]) -> String {
        guard !isUnset(id) else { return unsetLabel }
        return choices.first { $0.id == id }?.label ?? ModelLabel.readable(id)
    }
}
