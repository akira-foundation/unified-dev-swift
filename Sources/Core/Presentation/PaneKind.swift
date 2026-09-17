import Foundation

public enum PaneKind: String, CaseIterable, Identifiable, Sendable {
    case chat
    case terminal
    case browser

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .chat: PaneNaming.chat
        case .terminal: PaneNaming.terminal
        case .browser: PaneNaming.browser
        }
    }

    public var symbol: String {
        switch self {
        case .chat: PaneGlyph.chat
        case .terminal: PaneGlyph.terminal
        case .browser: PaneGlyph.browser
        }
    }
}
