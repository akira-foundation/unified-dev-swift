import Foundation

public enum ReviewViewedShortcut {
    public static func isArmed(hasFile: Bool, isTakingText: Bool) -> Bool {
        hasFile && !isTakingText
    }
}
