import Foundation

public struct ModelListFailure: Sendable, Hashable, Identifiable {
    public let kind: AgentKind
    public let complaint: String
    public let agentIsInstalled: Bool

    public var id: AgentKind { kind }

    public init(kind: AgentKind, error: any Error, agentIsInstalled: Bool) {
        self.kind = kind
        complaint = error.readableMessage.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        self.agentIsInstalled = agentIsInstalled
    }

    public var sentence: String { "\(kind.label) could not list its models. \(complaint)" }

    public static func hasGivenUp(
        on kind: AgentKind, among failures: [AgentKind: ModelListFailure], isLoading: Bool
    ) -> Bool {
        !isLoading && failures[kind] != nil
    }

    public static func reported(_ failures: [AgentKind: ModelListFailure]) -> [ModelListFailure] {
        AgentKind.allCases.compactMap { failures[$0] }.filter(\.agentIsInstalled)
    }
}
