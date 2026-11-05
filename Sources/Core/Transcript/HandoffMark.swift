import Foundation

public enum HandoffMark: Codable, Sendable, Equatable {
    case continued(agent: AgentKind, model: String, from: AgentKind)
    case resuming

    public var sentence: String {
        switch self {
        case .continued(let agent, let model, _): "Continued with \(agent.label) · \(model)"
        case .resuming: "Resuming the interrupted task"
        }
    }

    public var payload: Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    public static func decode(_ payload: Data) -> HandoffMark? {
        try? JSONDecoder().decode(HandoffMark.self, from: payload)
    }

    static func lastLeavingAgent(in rows: [Message]) -> AgentKind? {
        for row in rows.reversed() where row.kind == .handoff {
            if case .continued(_, _, let from)? = decode(row.payload) { return from }
        }
        return nil
    }
}
