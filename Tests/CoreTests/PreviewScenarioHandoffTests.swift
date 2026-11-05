import Foundation
import Testing
@testable import Core

@Suite("A preview scenario that moves a chat to another agent")
struct PreviewScenarioHandoffTests {
    private func refusal(_ json: String) -> String {
        do {
            _ = try PreviewScenario.read(Data(json.utf8))
            return ""
        } catch {
            return String(describing: error)
        }
    }

    private func chat(_ messages: String, agent: String = "") -> String {
        """
        {"projects":[{"name":"a","workspaces":[{"name":"w","branch":"w","chats":[
          {"title":"Plan",\(agent)"messages":[\(messages)]}]}]}]}
        """
    }

    @Test("a chat names the agent it starts under, and a line moves it to another")
    func reading() throws {
        let read = try PreviewScenario.read(Data(chat(
            #"{"from":"user","text":"Go"},{"from":"agent","handoff":{"agent":"codex","model":"gpt-5.6-sol"}}"#,
            agent: #""agent":"claudeCode","model":"opus","#
        ).utf8))
        let seeded = read.projects[0].workspaces[0].chats[0]

        #expect(seeded.agent == .claudeCode)
        #expect(seeded.model == "opus")
        #expect(seeded.messages[1].handoff?.agent == .codex)
        #expect(seeded.messages[1].handoff?.model == "gpt-5.6-sol")
    }

    @Test("a move to the agent the chat already runs under, or one carrying prose, is refused")
    func refusedShapes() {
        #expect(
            refusal(chat(#"{"from":"agent","handoff":{"agent":"claudeCode","model":"opus"}}"#))
                .contains("already runs under")
        )
        #expect(
            refusal(chat(#"{"from":"agent","text":"Also","handoff":{"agent":"codex","model":"gpt-5.6-sol"}}"#))
                .contains("also carries prose")
        )
        #expect(
            refusal(chat(#"{"from":"agent","handoff":{"agent":"codex","model":" "}}"#))
                .contains("names no model")
        )
    }

    @Test("the scenario the switch walkthrough uses holds a chat that spoke under two agents")
    func theScenarioOnDisk() throws {
        let root = URL(fileURLWithPath: #filePath)
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .path
        let read = try PreviewScenario.read(path: root + "/Tools/scenarios/switch-agent-in-chat.json")
        let handoffs = read.projects.flatMap(\.workspaces).flatMap(\.chats).flatMap(\.messages).compactMap(\.handoff)

        #expect(!handoffs.isEmpty)
    }
}

@Suite("Seeding a chat that moves to another agent", .tags(.git, .subprocess), .scratchDirectory, .timeLimit(.minutes(1)))
struct PreviewScenarioHandoffSeedingTests {
    @Test("the divider is written between the two voices and the chat ends on the second agent")
    func writesTheDivider() async throws {
        let root = TestScratch.unique("preview-handoff")
        let manager = WorkspaceManager(
            store: try makeTestStore("preview-handoff"),
            workspacesRoot: URL(fileURLWithPath: root + "/workspaces", isDirectory: true)
        )
        let seeder = PreviewScenarioSeeder(manager: manager, scratchRoot: PreviewIdentity.scratch(in: root))
        _ = try await seeder.seed(PreviewScenario(projects: [
            PreviewScenario.Project(name: "ledger", workspaces: [
                PreviewScenario.Workspace(
                    name: "Switch",
                    branch: "switch",
                    chats: [PreviewScenario.Chat(title: "Plan", messages: [
                        PreviewScenario.Line(from: .user, text: "Go"),
                        PreviewScenario.Line(from: .agent, text: "Started."),
                        PreviewScenario.Line(
                            from: .agent,
                            handoff: PreviewScenario.Handoff(agent: .codex, model: "gpt-5.6-sol")
                        ),
                        PreviewScenario.Line(from: .agent, text: "Carrying on."),
                    ])]
                ),
            ]),
        ]))

        let repo = try #require(try await manager.store.repos().first)
        let workspace = try #require(try await manager.store.workspaces(repoID: repo.id).first)
        let session = try #require(try await manager.store.sessions(workspaceID: workspace.id).first)
        let rows = try await manager.store.messages(sessionID: session.id, afterSeq: -1)
        let segments = try await manager.store.segments(sessionID: session.id)
        let divider = try #require(rows.first { $0.kind == .handoff })

        #expect(rows.map(\.kind) == [.user, .assistantText, .handoff, .assistantText])
        #expect(HandoffMark.decode(divider.payload) == .continued(agent: .codex, model: "gpt-5.6-sol", from: .claudeCode))
        #expect(session.agentKind == .codex)
        #expect(try await manager.store.setting(ComposerControls.defaultsAppliedKey(sessionID: session.id)) == "1")
        #expect(segments.map(\.agentKind) == [.claudeCode, .codex])
        #expect(segments.last?.isActive == true)
    }
}
