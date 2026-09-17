import AppKit
import Core

@MainActor
enum RunScriptGlyph {
    private static var resolved: [String: Bool] = [:]

    static func symbol(for icon: String?) -> String {
        guard let icon = icon?.trimmingCharacters(in: .whitespaces), !icon.isEmpty else {
            return PaneGlyph.terminal
        }
        if let known = resolved[icon] { return known ? icon : PaneGlyph.terminal }
        let exists = NSImage(systemSymbolName: icon, accessibilityDescription: nil) != nil
        resolved[icon] = exists
        return exists ? icon : PaneGlyph.terminal
    }
}
