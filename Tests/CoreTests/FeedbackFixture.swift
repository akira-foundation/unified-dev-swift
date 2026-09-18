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
        theme: InstallPing.Theme = .dark,
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

    static func report(
        message: String = "the sidebar flickers",
        email: String? = nil,
        logs: String? = nil,
        images: [Feedback.Image] = [],
        token: String? = FeedbackFixture.token
    ) -> Feedback.Report {
        Feedback.Report(
            message: message, email: email, logs: logs, images: images, token: token,
            environment: environment()
        )
    }

    static func object(_ value: some Encodable) throws -> [String: Any] {
        let data = try Feedback.json(value)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    static func text(of body: Feedback.Body) -> String {
        String(decoding: body.data, as: UTF8.self)
    }
}
