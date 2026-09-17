import Foundation

public struct AgentModel: Sendable, Hashable, Identifiable {
    public let id: String
    public let displayName: String
    public let isDefault: Bool
    public let hidden: Bool
    public let supportedEfforts: [AgentModelEffort]
    public let defaultEffort: String

    public init(
        id: String,
        displayName: String,
        isDefault: Bool = false,
        hidden: Bool = false,
        supportedEfforts: [AgentModelEffort] = [],
        defaultEffort: String = ""
    ) {
        self.id = id
        self.displayName = displayName
        self.isDefault = isDefault
        self.hidden = hidden
        self.supportedEfforts = supportedEfforts
        self.defaultEffort = defaultEffort
    }

    public func resolvedEffort(preferring wanted: String) -> String {
        if supportedEfforts.contains(where: { $0.id == wanted }) { return wanted }
        if !defaultEffort.isEmpty { return defaultEffort }
        return supportedEfforts.first?.id ?? ""
    }

    public static func selection(requested: String?, from models: [AgentModel]) -> AgentModel? {
        let visible = models.filter { !$0.hidden }
        if let requested { return visible.first { $0.id == requested } }
        return visible.first { $0.isDefault } ?? visible.first
    }
}

public struct AgentModelEffort: Sendable, Hashable, Identifiable {
    public let id: String
    public let label: String

    public init(id: String, label: String) {
        self.id = id
        self.label = label
    }
}
