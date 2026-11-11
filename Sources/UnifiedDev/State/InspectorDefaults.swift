import Foundation

enum InspectorDefaults {
    private static let hiddenKey = "inspector.isHidden"

    static var isHidden: Bool {
        UserDefaults.standard.bool(forKey: hiddenKey)
    }

    static func remember(isVisible: Bool) {
        UserDefaults.standard.set(!isVisible, forKey: hiddenKey)
    }
}
