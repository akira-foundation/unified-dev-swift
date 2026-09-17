import Foundation

public enum PaneContent: Codable, Hashable, Sendable {
    case chat(SessionID)
    case tool(String)

    public var id: String {
        switch self {
        case .chat(let id): id.rawValue
        case .tool(let id): id
        }
    }

    public var isChat: Bool {
        if case .chat = self { return true }
        return false
    }
}
