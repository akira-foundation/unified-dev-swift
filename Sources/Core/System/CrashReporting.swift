import Foundation

public enum CrashReporting {
    public static let settingKey = "sendCrashReports"
    public static let isOnByDefault = true

    public static func isEligible(
        bundleIdentifier: String?, identity: BuildIdentity, enabled: Bool, debuggerAttached: Bool
    ) -> Bool {
        guard enabled, !debuggerAttached, bundleIdentifier == "io.akira.unifieddev" else { return false }
        switch identity {
        case .release, .master: return true
        case .local: return false
        }
    }

    public static func environment(for identity: BuildIdentity) -> String {
        switch identity {
        case .release: "production"
        case .master: "development"
        case .local: "testing"
        }
    }
}
