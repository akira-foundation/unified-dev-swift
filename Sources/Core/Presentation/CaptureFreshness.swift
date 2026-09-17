import Foundation

public enum CaptureFreshness: Equatable, Sendable {
    case current
    case stale
    case unknowable

    public static func of(builtAt: Date?, newestSourceChangeAt: Date?) -> CaptureFreshness {
        guard let builtAt, let newestSourceChangeAt else { return .unknowable }
        return newestSourceChangeAt > builtAt ? .stale : .current
    }

    public func refusal(flag: String) -> String? {
        guard self == .stale else { return nil }
        return """
            \(flag): this binary is older than the sources beside it, so the capture would show \
            the build from before your last change. Run `swift build` and take it again.
            """
    }
}
