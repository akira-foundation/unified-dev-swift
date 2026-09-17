import Foundation

public enum ComposerFocus {
    public static func shouldTakeKeyboard(
        wantsFocus: Bool, holdsKeyboard: Bool, isReportingChange: Bool
    ) -> Bool {
        wantsFocus && !holdsKeyboard && !isReportingChange
    }

    public static func shouldGiveUpKeyboard(wantsFocus: Bool, holdsKeyboard: Bool) -> Bool {
        !wantsFocus && holdsKeyboard
    }
}
