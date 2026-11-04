import Testing
import Foundation
@testable import Core

@Suite("What makes a running agent obsolete")
struct AgentRunnerFingerprintTests {
    private let work = AccountFixture.work
    private let personal = AccountFixture.personal

    private var session: Session {
        Session(workspaceID: nil, model: "opus", agentKind: .claudeCode)
    }

    private func fingerprint(
        _ session: Session, on account: AgentAccountHome?, orchestrates: Bool = false
    ) -> AgentRunnerFingerprint {
        AgentRunnerFingerprint(session: session, account: account, orchestrates: orchestrates)
    }

    @Test func changingOnlyTheAccountMakesTheRunnerObsolete() {
        let made = session
        #expect(fingerprint(made, on: work) != fingerprint(made, on: personal))
        #expect(fingerprint(made, on: work) == fingerprint(made, on: work))
    }

    @Test func movingBetweenNoAccountAndAnAccountMakesTheRunnerObsolete() {
        let made = session
        #expect(fingerprint(made, on: nil) != fingerprint(made, on: work))
        #expect(fingerprint(made, on: nil) == fingerprint(made, on: nil))
    }

    @Test func anAccountOfTheSameIdPointedAtAnotherFolderMakesTheRunnerObsolete() {
        let moved = AgentAccountHome(
            provider: work.provider, id: work.id,
            directory: URL(filePath: "/elsewhere", directoryHint: .isDirectory), isDefault: false
        )
        #expect(fingerprint(session, on: work) != fingerprint(session, on: moved))
    }

    @Test func theModelTheEffortThePermissionModeAndTheAgentAllMakeItObsolete() {
        var changed = session
        changed.model = "sonnet"
        #expect(fingerprint(session, on: work) != fingerprint(changed, on: work))

        changed = session
        changed.effort = "low"
        #expect(fingerprint(session, on: work) != fingerprint(changed, on: work))

        changed = session
        changed.permissionMode = .plan
        #expect(fingerprint(session, on: work) != fingerprint(changed, on: work))

        changed = session
        changed.agentKind = .codex
        #expect(fingerprint(session, on: work) != fingerprint(changed, on: work))
    }

    @Test func aWorkspaceThatOrchestratesMakesTheRunnerObsolete() {
        #expect(fingerprint(session, on: work, orchestrates: true) != fingerprint(session, on: work))
        #expect(
            fingerprint(session, on: work, orchestrates: true)
                == fingerprint(session, on: work, orchestrates: true)
        )
    }

    @Test func aSessionThatOnlyChangedItsTitleKeepsTheRunner() {
        var renamed = session
        renamed.title = "renamed"
        #expect(fingerprint(session, on: work) == fingerprint(renamed, on: work))
    }
}
