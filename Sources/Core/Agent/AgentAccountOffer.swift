import Foundation

public enum AgentAccountOffer: Sendable, Equatable {
    case available
    case unavailable(reason: String)

    public var isAvailable: Bool { self == .available }

    public static func make(for provider: AgentKind, codexStorageMode: CodexAuthStorageMode) -> AgentAccountOffer {
        let doubt = AgentAccountRoster.isolationDoubt(for: provider, codexStorageMode: codexStorageMode)
        let isolates = AgentAccountEnvironment.givesADirectory(to: provider)
        let verifies = AgentAccountLiveness.canAsk(about: provider)
        guard isolates, verifies, doubt == nil else {
            let because = doubt ?? "Unified Dev cannot keep a separate login apart or check it for this agent."
            return .unavailable(reason: "Unified Dev cannot add another \(provider.label) account. \(because)")
        }
        return .available
    }
}
