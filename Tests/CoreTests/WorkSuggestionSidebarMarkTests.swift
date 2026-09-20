import Foundation
import Testing
@testable import Core

@Suite("Where the sidebar's suggestions mark goes")
struct WorkSuggestionSidebarMarkTests {
    private func suggestion(
        _ id: String,
        chat: String = "c1",
        seq: Int? = 3,
        at seconds: TimeInterval,
        state: WorkSuggestion.State = .pending,
        workspace: String? = "w1"
    ) -> WorkSuggestion {
        WorkSuggestion(
            stored: WorkSuggestionID(id), workspaceID: workspace.map(WorkspaceID.init),
            sessionID: SessionID(chat), anchorSeq: seq, title: "Keep the last row", why: "Because.",
            prompt: "Do it.", target: .sameProject, state: state, failure: nil,
            createdAt: Date(timeIntervalSince1970: seconds), decidedAt: nil
        )
    }

    @Test("the oldest undecided one wins, whichever of the workspace's chats made it")
    func oldestAcrossChats() {
        let destination = WorkSuggestionSidebarMark.destination(in: [
            suggestion("s1", chat: "import", seq: 9, at: 300),
            suggestion("s2", chat: "review", seq: 4, at: 100),
            suggestion("s3", chat: "import", seq: 2, at: 200),
        ])

        #expect(destination?.suggestion == WorkSuggestionID("s2"))
        #expect(destination?.sessionID == SessionID("review"))
        #expect(destination?.workspaceID == WorkspaceID("w1"))
        #expect(destination?.anchorSeq == 4)
    }

    @Test("two made in the same instant are settled by the row each is anchored to")
    func tiesGoBySeq() {
        let destination = WorkSuggestionSidebarMark.destination(in: [
            suggestion("s1", seq: 12, at: 100),
            suggestion("s2", seq: 7, at: 100),
            suggestion("s3", seq: 20, at: 100),
        ])

        #expect(destination?.suggestion == WorkSuggestionID("s2"))
        #expect(destination?.anchorSeq == 7)
    }

    @Test("one that has never been anchored waits behind one of the same age that has")
    func anchoredFirst() {
        let destination = WorkSuggestionSidebarMark.destination(in: [
            suggestion("s1", seq: nil, at: 100),
            suggestion("s2", seq: 40, at: 100),
        ])

        #expect(destination?.suggestion == WorkSuggestionID("s2"))
    }

    @Test("a decided one is passed over, and the oldest still waiting is taken instead", arguments: [
        WorkSuggestion.State.dismissed,
        .withdrawn,
        .startedWorkspace(WorkspaceID("w2"), name: "Parser"),
        .startedHere(SessionID("c2"), name: "Parser"),
    ])
    func decidedPassedOver(state: WorkSuggestion.State) {
        let destination = WorkSuggestionSidebarMark.destination(in: [
            suggestion("s1", seq: 2, at: 100, state: state),
            suggestion("s2", seq: 8, at: 200),
        ])

        #expect(destination?.suggestion == WorkSuggestionID("s2"))
    }

    @Test("a suggestion still starting is still waiting, because nobody has answered it")
    func startingStillCounts() {
        let destination = WorkSuggestionSidebarMark.destination(in: [
            suggestion("s1", seq: 2, at: 100, state: .starting),
        ])

        #expect(destination?.suggestion == WorkSuggestionID("s1"))
    }

    @Test("with nothing left to decide there is nowhere to go, which is when no mark is drawn either")
    func nothingUndecided() {
        let settled = [
            suggestion("s1", seq: 2, at: 100, state: .dismissed),
            suggestion("s2", seq: 8, at: 200, state: .startedWorkspace(WorkspaceID("w2"), name: "Parser")),
        ]

        #expect(WorkSuggestionSidebarMark.destination(in: settled) == nil)
        #expect(WorkSuggestionSidebarMark.destination(in: []) == nil)
        #expect(WorkSuggestionSidebarMark.label(undecided: 0) == nil)
    }

    @Test("an Ask chat's suggestion belongs to no workspace, so no sidebar row leads to it")
    func noWorkspace() {
        #expect(WorkSuggestionSidebarMark.destination(in: [
            suggestion("s1", seq: 2, at: 100, workspace: nil),
        ]) == nil)
    }
}

@Suite("A workspace's suggestions, read for the sidebar mark", .tags(.persistence), .scratchDirectory)
struct WorkSuggestionWorkspaceReadTests {
    @Test("an archived chat's suggestions are left out, exactly as they are left out of the count")
    func archivedChatIgnored() async throws {
        let store = try makeTestStore("suggestion-workspace-read")
        let repo = try await store.upsert(Repo(name: "lantern", path: "/tmp/lantern", defaultBranch: "main"))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "Importer", branch: "importer",
            path: "/tmp/lantern-importer", baseBranch: "main"
        ))
        let old = try await store.upsert(Session(workspaceID: workspace.id, title: "Review"))
        let live = try await store.upsert(Session(workspaceID: workspace.id, title: "Import"))
        func suggestion(_ title: String, in chat: Session) -> WorkSuggestion {
            WorkSuggestion(
                workspaceID: workspace.id, sessionID: chat.id, title: title, why: "Because.",
                prompt: "Do it.", target: .sameProject
            )
        }
        _ = try await store.addWorkSuggestion(suggestion("Older, in the chat about to be archived", in: old))
        _ = try await store.addWorkSuggestion(suggestion("Newer, in the chat that stays", in: live))

        _ = try await store.update(sessionID: old.id) { $0.archivedAt = Date() }
        let read = try await store.workSuggestions(workspaceID: workspace.id)
        let destination = WorkSuggestionSidebarMark.destination(in: read)

        #expect(read.map(\.title) == ["Newer, in the chat that stays"])
        #expect(destination?.sessionID == live.id)
        #expect(try await store.undecidedWorkSuggestionCounts() == [workspace.id: 1])
    }

    @Test("the read carries the row each card sits on, so the transcript can be taken to it")
    func carriesTheAnchor() async throws {
        let store = try makeTestStore("suggestion-workspace-anchor")
        let repo = try await store.upsert(Repo(name: "lantern", path: "/tmp/lantern", defaultBranch: "main"))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "Importer", branch: "importer",
            path: "/tmp/lantern-importer", baseBranch: "main"
        ))
        let chat = try await store.upsert(Session(workspaceID: workspace.id, title: "Import"))
        let added = try #require(try await store.addWorkSuggestion(WorkSuggestion(
            workspaceID: workspace.id, sessionID: chat.id, title: "Keep the last row",
            why: "Because.", prompt: "Do it.", target: .sameProject
        )).suggestion)

        let destination = WorkSuggestionSidebarMark.destination(
            in: try await store.workSuggestions(workspaceID: workspace.id)
        )

        #expect(destination?.suggestion == added.id)
        #expect(destination?.anchorSeq == added.anchorSeq)
        #expect(destination?.anchorSeq != nil)
    }
}
