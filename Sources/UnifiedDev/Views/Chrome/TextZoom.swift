import AppKit
import Foundation
import Core

@MainActor
enum TextZoom {
    static func zoomIn() { adjust(by: 1) }

    static func zoomOut() { adjust(by: -1) }

    static func actualSize() {
        if focusedTerminal != nil {
            TerminalTextSize.override = nil
        } else {
            ChatTextSize.current = .defaultChoice
        }
    }

    static var canZoomIn: Bool { canAdjust(by: 1) }

    static var canZoomOut: Bool { canAdjust(by: -1) }

    static var canResetSize: Bool {
        if focusedTerminal != nil { return TerminalTextSize.override != nil }
        return ChatTextSize.current != .defaultChoice
    }

    private static func adjust(by steps: Int) {
        if let terminal = focusedTerminal {
            TerminalTextSize.adjust(from: terminal.fontSize, by: TerminalTextSize.step * CGFloat(steps))
        } else if let next = ChatTextSize.current.stepped(by: steps) {
            ChatTextSize.current = next
        }
    }

    private static func canAdjust(by steps: Int) -> Bool {
        if let terminal = focusedTerminal {
            return TerminalTextSize.canAdjust(
                from: terminal.fontSize, by: TerminalTextSize.step * CGFloat(steps)
            )
        }
        return ChatTextSize.current.stepped(by: steps) != nil
    }

    private static var focusedTerminal: AppTerminalView? {
        var responder = NSApp.keyWindow?.firstResponder
        while let current = responder {
            if let terminal = current as? AppTerminalView { return terminal }
            responder = current.nextResponder
        }
        return nil
    }
}
