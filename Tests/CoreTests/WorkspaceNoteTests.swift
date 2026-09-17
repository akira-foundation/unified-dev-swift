import Testing
import Foundation
@testable import Core

@Suite("Workspace notes", .tags(.persistence), .scratchDirectory)
struct WorkspaceNoteTests {
    private func seed(_ store: Store) async throws -> Workspace {
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        return try await store.upsert(Workspace(
            repoID: repo.id, name: "original", branch: "feature/original",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
    }

    @Test("a note comes back as it was typed")
    func roundTrips() async throws {
        let store = try makeTestStore("notes")
        let workspace = try await seed(store)

        try await store.saveNote(workspaceID: workspace.id, body: "check the retry\n\nand the timeout")

        #expect(try await store.note(workspaceID: workspace.id)?.body == "check the retry\n\nand the timeout")
    }

    @Test("a workspace that has never had a note has none")
    func noneByDefault() async throws {
        let store = try makeTestStore("notes")
        let workspace = try await seed(store)

        #expect(try await store.note(workspaceID: workspace.id) == nil)
    }

    @Test("emptying a note removes it rather than storing a blank")
    func emptyingRemovesIt() async throws {
        let store = try makeTestStore("notes")
        let workspace = try await seed(store)

        try await store.saveNote(workspaceID: workspace.id, body: "something")
        try await store.saveNote(workspaceID: workspace.id, body: "  \n ")

        #expect(try await store.note(workspaceID: workspace.id) == nil)
    }

    @Test("a note belongs to one workspace")
    func notesDoNotLeakBetweenWorkspaces() async throws {
        let store = try makeTestStore("notes")
        let first = try await seed(store)
        let second = try await seed(store)

        try await store.saveNote(workspaceID: first.id, body: "first")

        #expect(try await store.note(workspaceID: first.id)?.body == "first")
        #expect(try await store.note(workspaceID: second.id) == nil)
    }

    @Test("archiving a workspace keeps its note")
    func survivesArchiving() async throws {
        let store = try makeTestStore("notes")
        let workspace = try await seed(store)
        try await store.saveNote(workspaceID: workspace.id, body: "gave up on the websocket")

        try await store.update(workspaceID: workspace.id) { $0.archive() }

        #expect(try await store.workspace(id: workspace.id)?.state == .archived)
        #expect(try await store.note(workspaceID: workspace.id)?.body == "gave up on the websocket")
    }

    @Test("deleting a workspace takes its note with it")
    func cascadesOnDelete() async throws {
        let store = try makeTestStore("notes")
        let workspace = try await seed(store)
        try await store.saveNote(workspaceID: workspace.id, body: "gone soon")

        try await store.deleteWorkspace(id: workspace.id)

        #expect(try await store.note(workspaceID: workspace.id) == nil)
    }

    @Test("saving a note leaves the workspace row alone")
    func doesNotWriteTheWorkspaceRow() async throws {
        let store = try makeTestStore("notes")
        let workspace = try await seed(store)

        try await store.updateDiffStat(workspaceID: workspace.id, additions: 12, deletions: 3, files: 2)
        try await store.update(workspaceID: workspace.id) { $0.name = "renamed by the namer" }
        try await store.saveNote(workspaceID: workspace.id, body: "typed over the top of all that")

        let stored = try #require(try await store.workspace(id: workspace.id))
        #expect(stored.additions == 12)
        #expect(stored.deletions == 3)
        #expect(stored.changedFiles == 2)
        #expect(stored.name == "renamed by the namer")
    }

    @Test("identical text is not worth a write")
    func skipsAnUnchangedNote() {
        #expect(!WorkspaceNote.needsSave(stored: "same", typed: "same"))
        #expect(WorkspaceNote.needsSave(stored: "same", typed: "same "))
        #expect(WorkspaceNote.needsSave(stored: "", typed: "new"))
    }

    @Test("blank text and no text are the same note")
    func blankIsNothing() {
        #expect(!WorkspaceNote.needsSave(stored: "", typed: "  \n\t "))
        #expect(WorkspaceNote.storable(" \n ").isEmpty)
        #expect(WorkspaceNote.storable("a\n") == "a\n")
    }
}

@Suite("What a note says when it cannot be read")
struct WorkspaceNoteTroubleTests {
    @Test("the unreadable sentence reads as paragraphs")
    func unreadableIsBrokenUp() {
        let paragraphs = WorkspaceNote.unreadable.components(separatedBy: "\n\n")
        #expect(paragraphs.count >= 3)
        for paragraph in paragraphs {
            #expect(!paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            #expect(!paragraph.contains("\n"))
        }
    }

    @Test("it says the note has not been lost")
    func itSaysNothingIsLost() {
        #expect(WorkspaceNote.unreadable.contains("Nothing has been lost"))
    }

    @Test("the footer's refusal is left as one line")
    func theFooterStaysOneLine() {
        #expect(!WorkspaceNote.unwritable.contains("\n"))
    }
}
