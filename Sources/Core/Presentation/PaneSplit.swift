import Foundation

public enum CenterTabKind: String, Codable, Sendable, CaseIterable {
    case terminal
    case browser
    case review
    case notes
}

public enum PaneDuplicateOutcome: Equatable, Sendable {
    case sameContent
    case freshTerminal
    case freshBrowser
    case nothing

    public var opensAPane: Bool { self != .nothing }

    public var sameAgainKind: PaneKind? {
        switch self {
        case .sameContent: .chat
        case .freshTerminal: .terminal
        case .freshBrowser: .browser
        case .nothing: nil
        }
    }
}

public enum PaneSplit {
    public static func duplicating(_ content: PaneContent, tabKind: CenterTabKind?) -> PaneDuplicateOutcome {
        switch content {
        case .chat:
            return .sameContent
        case .tool:
            switch tabKind {
            case .terminal: return .freshTerminal
            case .browser: return .freshBrowser
            case .review, .notes, nil: return .nothing
            }
        }
    }
}
