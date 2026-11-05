import Foundation

public enum HandoffMark: Codable, Sendable, Equatable {
    case continued(agent: AgentKind, model: String)
    case resuming

    public var sentence: String {
        switch self {
        case .continued(let agent, let model): "Continued with \(agent.label) · \(model)"
        case .resuming: "Resuming the interrupted task"
        }
    }

    public var payload: Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    public static func decode(_ payload: Data) -> HandoffMark? {
        try? JSONDecoder().decode(HandoffMark.self, from: payload)
    }
}
