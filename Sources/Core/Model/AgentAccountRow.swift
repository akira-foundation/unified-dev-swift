import Foundation

public struct AgentAccountRow: Sendable, Hashable {
    public var id: AgentAccountID
    public var provider: AgentKind
    public var directory: String
    public var isDefault: Bool
    public var label: String
    public var createdAt: Date
    public var profileID: ProfileID

    public init(
        id: AgentAccountID,
        provider: AgentKind,
        directory: String,
        isDefault: Bool = false,
        label: String = "",
        createdAt: Date = Date(),
        profileID: ProfileID = .initial
    ) {
        self.id = id
        self.provider = provider
        self.directory = directory
        self.isDefault = isDefault
        self.label = label
        self.createdAt = createdAt
        self.profileID = profileID
    }
}
