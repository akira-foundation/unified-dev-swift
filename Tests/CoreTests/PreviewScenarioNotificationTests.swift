import Testing
import Foundation
@testable import Core

@Suite("Notification inbox scenario")
struct NotificationInboxScenarioTests {
    private let project = PreviewScenario.Project(
        name: "ledger",
        workspaces: [PreviewScenario.Workspace(
            name: "Close", branch: "close",
            chats: [PreviewScenario.Chat(title: "Chat", messages: [])]
        )]
    )

    @Test("a notification that names what the scenario declares is accepted")
    func accepted() {
        let scenario = PreviewScenario(projects: [project], notifications: [
            .init(event: .needsInput, project: "ledger", workspace: "Close", chat: "Chat"),
            .init(event: .setupFailed, project: "ledger", workspace: "Anything", removed: true),
        ])

        #expect(scenario.notificationProblems.isEmpty)
    }

    @Test("a notification that names what is not declared is refused", arguments: [
        PreviewScenario.SeededNotification(event: .needsInput, project: "nope", workspace: "Close"),
        PreviewScenario.SeededNotification(event: .needsInput, project: "ledger", workspace: "nope"),
        PreviewScenario.SeededNotification(event: .needsInput, project: "ledger", workspace: "Close", chat: "nope"),
    ])
    func refused(notification: PreviewScenario.SeededNotification) {
        let scenario = PreviewScenario(projects: [project], notifications: [notification])

        #expect(scenario.notificationProblems.count == 1)
    }

    @Test("the fields of a seeded notification default when absent")
    func decodesDefaults() throws {
        let json = #"{"event":"turnFinished","project":"ledger","workspace":"Close"}"#

        let decoded = try JSONDecoder().decode(PreviewScenario.SeededNotification.self, from: Data(json.utf8))

        #expect(decoded == .init(event: .turnFinished, project: "ledger", workspace: "Close"))
    }
}
