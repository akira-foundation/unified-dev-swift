import Foundation

public struct ChosenAgentAccount: Sendable, Hashable {
    public let provider: AgentKind
    public let home: AgentAccountHome?

    public init(_ home: AgentAccountHome) {
        self.provider = home.provider
        self.home = home
    }

    public init(inheritedBy provider: AgentKind) {
        self.provider = provider
        self.home = nil
    }
}
