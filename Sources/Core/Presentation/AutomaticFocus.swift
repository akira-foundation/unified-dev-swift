import Foundation

public enum AutomaticFocus {
    public static func mayUpdateResponder(
        applicationIsActive: Bool, windowIsKey: Bool, windowIsVisible: Bool
    ) -> Bool {
        !windowIsVisible || (applicationIsActive && windowIsKey)
    }
}
