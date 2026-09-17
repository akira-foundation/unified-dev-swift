import AppKit
import Core

enum TerminalPaneCommand: Sendable, Hashable {
    case split(SplitAxis, PaneKind)
    case focus(SplitDirection)
    case close
    case toggleZoom

    init?(key: String, modifiers: NSEvent.ModifierFlags) {
        let shift = modifiers.contains(.shift)
        let option = modifiers.contains(.option)

        if option, let direction = Self.direction(for: key) {
            self = .focus(direction)
            return
        }

        switch key {
        case "d" where !option:
            self = .split(shift ? .vertical : .horizontal, .terminal)
        case "w" where !shift && !option:
            self = .close
        case "\r", "\u{3}":
            guard shift, !option else { return nil }
            self = .toggleZoom
        default:
            return nil
        }
    }

    private static func direction(for key: String) -> SplitDirection? {
        guard key.unicodeScalars.count == 1, let scalar = key.unicodeScalars.first else { return nil }
        switch Int(scalar.value) {
        case NSLeftArrowFunctionKey: return .left
        case NSRightArrowFunctionKey: return .right
        case NSUpArrowFunctionKey: return .up
        case NSDownArrowFunctionKey: return .down
        default: return nil
        }
    }
}
