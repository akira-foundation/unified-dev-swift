import Foundation

public struct SetupRunOffer: Sendable, Hashable {
    public let title: String

    public let isEnabled: Bool

    public static func offer(
        hasSetupScript: Bool,
        hasRunSetup: Bool,
        isRunning: Bool
    ) -> SetupRunOffer? {
        guard hasSetupScript else { return nil }
        return SetupRunOffer(
            title: hasRunSetup ? "Run Setup Again" : "Run Setup",
            isEnabled: !isRunning
        )
    }
}
