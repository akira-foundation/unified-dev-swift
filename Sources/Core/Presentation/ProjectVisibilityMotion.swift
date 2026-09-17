import Foundation

public enum ProjectVisibilityMotion: Equatable, Sendable {
    case instant
    case dim(seconds: Double)
    case reflow(seconds: Double)

    public var seconds: Double? {
        switch self {
        case .instant: nil
        case .dim(let seconds), .reflow(let seconds): seconds
        }
    }

    public static let seconds = 0.25

    public static func hideGesture(
        showingHidden: Bool, reduceMotion: Bool
    ) -> ProjectVisibilityMotion {
        guard !reduceMotion else { return .instant }
        return showingHidden ? .dim(seconds: seconds) : .reflow(seconds: seconds)
    }

    public static func filterToggle(reduceMotion: Bool) -> ProjectVisibilityMotion {
        reduceMotion ? .instant : .reflow(seconds: seconds)
    }

    public static func subagentRemoval(reduceMotion: Bool) -> ProjectVisibilityMotion {
        reduceMotion ? .instant : .reflow(seconds: seconds)
    }

    public var fadesArrivals: Bool {
        if case .reflow = self { return true }
        return false
    }
}
