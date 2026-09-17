import Core

enum PaneWait: Equatable, Sendable {
    case sessions(WorkspaceID)
    case conversation(SessionID)

    var label: String {
        switch self {
        case .sessions: "Opening the workspace"
        case .conversation: "Reading the conversation"
        }
    }
}
