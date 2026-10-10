import Foundation
import Testing
@testable import Core

enum FeedbackFixture {
    static let token = "3F2504E0-4F89-11D3-9A0C-0305E82C3301"
    static let pngBytes = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x01])

    static func environment(
        appVersion: String = "0.4.0",
        appBuild: String = "412",
        macOSVersion: String = "26.1.0",
        architecture: Feedback.Architecture = .arm64,
        translated: Bool? = false,
        installSource: Feedback.InstallSource = .release,
        agent: String = "claude",
        agentVersion: String = "2.1.234",
        availableAgents: [String] = ["codex", "claude"],
        permissionMode: String = "accept-edits",
        theme: SystemReadings.Theme = .dark,
        displayScale: Double = 2,
        locale: String = "nl-BE"
    ) -> Feedback.Environment {
        Feedback.Environment(
            appVersion: appVersion,
            appBuild: appBuild,
            macOSVersion: macOSVersion,
            architecture: architecture,
            translated: translated,
            installSource: installSource,
            agent: agent,
            agentVersion: agentVersion,
            availableAgents: availableAgents,
            permissionMode: permissionMode,
            theme: theme,
            displayScale: displayScale,
            locale: locale
        )
    }
}
