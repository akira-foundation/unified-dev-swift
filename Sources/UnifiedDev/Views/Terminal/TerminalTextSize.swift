import AppKit
import SwiftUI

@MainActor
enum TerminalTextSize {
    static let defaultsKey = "terminal.fontSize"

    static let range: ClosedRange<CGFloat> = 9...28

    static let step: CGFloat = 1

    static var override: CGFloat? {
        get {
            let stored = CGFloat(UserDefaults.standard.double(forKey: defaultsKey))
            guard stored > 0 else { return nil }
            return min(max(stored, range.lowerBound), range.upperBound)
        }
        set {
            guard let newValue else {
                UserDefaults.standard.removeObject(forKey: defaultsKey)
                return
            }
            let clamped = min(max(newValue, range.lowerBound), range.upperBound)
            UserDefaults.standard.set(Double(clamped), forKey: defaultsKey)
        }
    }

    static func adjust(from current: CGFloat, by delta: CGFloat) {
        override = current + delta
    }

    static func canAdjust(from current: CGFloat, by delta: CGFloat) -> Bool {
        min(max(current + delta, range.lowerBound), range.upperBound) != current
    }

    static func ghosttyDefault(for appearance: NSAppearance) -> CGFloat? {
        guard UserDefaults.standard.object(forKey: TerminalGhostty.defaultsKey) as? Bool ?? true
        else { return nil }
        return TerminalGhostty.theme(for: appearance)?.fontSize.map { CGFloat($0) }
    }

    static var systemDefault: CGFloat {
        NSFont.preferredFont(forTextStyle: .callout).pointSize
    }

    static func fallback(for appearance: NSAppearance) -> CGFloat {
        ghosttyDefault(for: appearance) ?? systemDefault
    }
}
