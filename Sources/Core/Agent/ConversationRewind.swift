import Foundation

public enum ConversationRewindError: Error, LocalizedError, Sendable {
    case unsupported
    case busy
    case missingTurn
    case invalidHistory
    case crossesHandoff

    public var errorDescription: String? {
        switch self {
        case .unsupported: "This agent does not support conversation rewind."
        case .busy: "Stop all work in this conversation before rewinding."
        case .missingTurn: "The selected turn is no longer in the agent's history."
        case .invalidHistory: "The agent returned incomplete conversation history. Nothing was rewound."
        case .crossesHandoff: "This turn ran before the agent changed, so it cannot be rewound."
        }
    }
}
