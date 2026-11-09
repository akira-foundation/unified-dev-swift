import Foundation

public enum FullScreenToolbarGround {
    private static let transitionAllowance: TimeInterval = 5

    public static func applies(isFullScreen: Bool, screenTopInset: CGFloat) -> Bool {
        isFullScreen && screenTopInset > 0
    }

    public static func isTransitionOver(startedAt: Date?, now: Date) -> Bool {
        guard let startedAt else { return true }
        return now.timeIntervalSince(startedAt) >= transitionAllowance
    }

    public static func correctedHeight(current: CGFloat, toolbarBand: CGFloat) -> CGFloat? {
        guard toolbarBand > 0, current > toolbarBand + 0.5 else { return nil }
        return toolbarBand
    }
}
