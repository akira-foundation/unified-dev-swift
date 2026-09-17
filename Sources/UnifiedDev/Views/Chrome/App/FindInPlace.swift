import AppKit
import SwiftTerm

@MainActor
enum FindInPlace {
    static var isAvailable: Bool { target() != nil }

    @discardableResult
    static func perform(_ action: NSTextFinder.Action) -> Bool {
        guard let target = target() else { return false }
        let item = NSMenuItem()
        item.tag = action.rawValue
        target.performTextFinderAction(item)
        return true
    }

    private static func target() -> NSResponder? {
        var responder = NSApp.keyWindow?.firstResponder
        while let current = responder {
            if current is SwiftTerm.TerminalView { return current }
            if let text = current as? NSTextView, text.usesFindBar { return text }
            responder = current.nextResponder
        }
        return nil
    }
}
