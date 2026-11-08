import Foundation

public struct ComposerEffortChoice: Sendable, Equatable {
    public let id: String
    public let label: String

    public init(id: String, label: String) {
        self.id = id
        self.label = label
    }
}

public enum ComposerEffort {
    public static let unsetID = ""
    public static let unsetLabel = "Agent default"

    public static func isUnset(_ id: String) -> Bool {
        id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public static func choices(
        _ supported: [ComposerEffortChoice],
        offeringUnset: Bool
    ) -> [ComposerEffortChoice] {
        guard offeringUnset, !supported.contains(where: { isUnset($0.id) }) else { return supported }
        return [ComposerEffortChoice(id: unsetID, label: unsetLabel)] + supported
    }

    public static func label(for id: String, among choices: [ComposerEffortChoice]) -> String {
        guard !isUnset(id) else { return unsetLabel }
        return choices.first { $0.id == id }?.label ?? ModelLabel.readable(id)
    }
}
