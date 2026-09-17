import Testing
import Foundation
@testable import Core

@Suite("Archive cleanup", .tags(.persistence), .scratchDirectory)
struct ArchiveCleanupTests {
    @Test("only archived workspaces are measured")
    func measuresOnlyArchived() async throws {
        let store = try makeTestStore("archive-scope")
        let repo = try await store.upsert(Repo(name: "there-there", path: "/tmp/tt"))
        _ = try await store.upsert(Workspace(
            repoID: repo.id, name: "live", branch: "b1", path: "/tmp/live", baseBranch: "main"
        ))
        _ = try await archive(store, repo: repo, name: "old", branch: "b2")

        let footprints = try await store.archivedFootprints()
        #expect(footprints.count == 1)
        #expect(footprints[0].workspace.name == "old")
        #expect(footprints[0].repoName == "there-there")
    }

    @Test("the transcript is measured in the bytes its payloads actually hold")
    func measuresTranscriptBytes() async throws {
        let store = try makeTestStore("archive-bytes")
        let repo = try await store.upsert(Repo(name: "r", path: "/tmp/r"))
        let workspace = try await archive(store, repo: repo, name: "w", branch: "b")
        let session = try await store.upsert(Session(workspaceID: workspace.id, title: "S", model: "opus"))

        var expected = 0
        for index in 0..<20 {
            let payload = Data(String(repeating: "x", count: 100 + index).utf8)
            expected += payload.count
            try await store.appendNext(sessionID: session.id, kind: .assistantText, payload: payload)
        }

        let footprint = try #require(try await store.archivedFootprints().first)
        #expect(footprint.messageCount == 20)
        #expect(footprint.sessionCount == 1)
        #expect(footprint.transcriptBytes == expected)
    }

    @Test("a workspace with no transcript at all is still a row")
    func measuresAnEmptyWorkspace() async throws {
        let store = try makeTestStore("archive-empty")
        let repo = try await store.upsert(Repo(name: "r", path: "/tmp/r"))
        _ = try await archive(store, repo: repo, name: "w", branch: "b")

        let footprint = try #require(try await store.archivedFootprints().first)
        #expect(footprint.messageCount == 0)
        #expect(footprint.transcriptBytes == 0)
        #expect(footprint.hasNote == false)
        #expect(footprint.reviewCommentCount == 0)
    }

    @Test("review comments and notes are counted once, whatever the transcript is doing")
    func countsAsideFromTheTranscript() async throws {
        let store = try makeTestStore("archive-aside")
        let repo = try await store.upsert(Repo(name: "r", path: "/tmp/r"))
        let workspace = try await archive(store, repo: repo, name: "w", branch: "b")
        let session = try await store.upsert(Session(workspaceID: workspace.id, title: "S", model: "opus"))
        for _ in 0..<9 {
            try await store.appendNext(
                sessionID: session.id, kind: .assistantText, payload: Data("{}".utf8)
            )
        }
        for line in 1...3 {
            _ = try await store.upsert(ReviewComment(
                workspaceID: workspace.id, filePath: "a.swift",
                anchor: ReviewCommentAnchor(line: line, text: "x"), body: "look at this"
            ))
        }
        try await store.saveNote(workspaceID: workspace.id, body: "why this stopped")

        let footprint = try #require(try await store.archivedFootprints().first)
        #expect(footprint.messageCount == 9)
        #expect(footprint.reviewCommentCount == 3)
        #expect(footprint.hasNote)
        #expect(footprint.otherBytes > 0)
    }

    @Test("deleting takes the transcript, the search index and the rows around it")
    func deleteTakesEverything() async throws {
        let store = try makeTestStore("archive-delete")
        let repo = try await store.upsert(Repo(name: "r", path: "/tmp/r"))
        let workspace = try await archive(store, repo: repo, name: "w", branch: "b")
        let session = try await store.upsert(Session(workspaceID: workspace.id, title: "S", model: "opus"))
        try await store.appendNext(
            sessionID: session.id, kind: .assistantText,
            payload: Data("{\"text\":\"an unrepeatable word: zarquon\"}".utf8)
        )
        _ = try await store.upsert(ReviewComment(
            workspaceID: workspace.id, filePath: "a.swift",
            anchor: ReviewCommentAnchor(line: 1, text: "x"), body: "look"
        ))
        try await store.saveNote(workspaceID: workspace.id, body: "a note")
        try await store.saveDraft(sessionID: session.id, body: "half a thought")

        #expect(try await store.searchTranscripts("zarquon").count == 1)

        let deleted = try await store.deleteArchivedWorkspaces(ids: [workspace.id])
        #expect(deleted == 1)

        #expect(try await store.workspace(id: workspace.id) == nil)
        #expect(try await store.sessions(workspaceID: workspace.id).isEmpty)
        #expect(try await store.messages(sessionID: session.id).isEmpty)
        #expect(try await store.reviewComments(workspaceID: workspace.id).isEmpty)
        #expect(try await store.note(workspaceID: workspace.id) == nil)
        #expect(try await store.draft(sessionID: session.id).isEmpty)
        #expect(try await store.searchTranscripts("zarquon").isEmpty)
    }

    @Test("a workspace that is not archived is refused, whoever asks")
    func refusesALiveWorkspace() async throws {
        let store = try makeTestStore("archive-refuse")
        let repo = try await store.upsert(Repo(name: "r", path: "/tmp/r"))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "live", branch: "b", path: "/tmp/live", baseBranch: "main"
        ))
        let session = try await store.upsert(Session(workspaceID: workspace.id, title: "S", model: "opus"))
        try await store.appendNext(sessionID: session.id, kind: .assistantText, payload: Data("{}".utf8))

        #expect(try await store.deleteArchivedWorkspaces(ids: [workspace.id]) == 0)
        #expect(try await store.workspace(id: workspace.id) != nil)
        #expect(try await store.messages(sessionID: session.id).count == 1)
    }

    @Test("a bulk delete takes the archived rows and leaves the live one standing")
    func deletesInBulk() async throws {
        let store = try makeTestStore("archive-bulk")
        let repo = try await store.upsert(Repo(name: "r", path: "/tmp/r"))
        let first = try await archive(store, repo: repo, name: "one", branch: "b1")
        let second = try await archive(store, repo: repo, name: "two", branch: "b2")
        let live = try await store.upsert(Workspace(
            repoID: repo.id, name: "live", branch: "b3", path: "/tmp/live", baseBranch: "main"
        ))

        #expect(try await store.deleteArchivedWorkspaces(ids: [first.id, second.id, live.id]) == 2)
        #expect(try await store.archivedFootprints().isEmpty)
        #expect(try await store.workspace(id: live.id) != nil)
    }

    @Test("deleting a selection of several takes exactly those rows and no others")
    func deletesExactlyTheSelection() async throws {
        let store = try makeTestStore("archive-selection")
        let repo = try await store.upsert(Repo(name: "r", path: "/tmp/r"))
        let alpha = try await archive(store, repo: repo, name: "alpha", branch: "b1")
        let bravo = try await archive(store, repo: repo, name: "bravo", branch: "b2")
        let charlie = try await archive(store, repo: repo, name: "charlie", branch: "b3")
        let delta = try await archive(store, repo: repo, name: "delta", branch: "b4")

        var sessions: [WorkspaceID: SessionID] = [:]
        for workspace in [alpha, bravo, charlie, delta] {
            let session = try await store.upsert(
                Session(workspaceID: workspace.id, title: "S", model: "opus")
            )
            sessions[workspace.id] = session.id
            try await store.appendNext(
                sessionID: session.id, kind: .assistantText,
                payload: Data("{\"text\":\"\(workspace.name)\"}".utf8)
            )
        }

        let footprints = try await store.archivedFootprints()
        let selection: Set<WorkspaceID> = [alpha.id, bravo.id, charlie.id]
        let target = footprints.filter { selection.contains($0.id) }
        #expect(ArchiveDeletion(target).title == "Delete everything Unified Dev kept about 3 archived workspaces?")

        let removed = try await store.deleteArchivedWorkspaces(ids: target.map(\.id))
        #expect(removed == 3)

        for id in selection {
            #expect(try await store.workspace(id: id) == nil)
            #expect(try await store.messages(sessionID: sessions[id]!).isEmpty)
        }
        #expect(try await store.workspace(id: delta.id) != nil)
        #expect(try await store.messages(sessionID: sessions[delta.id]!).count == 1)
        #expect(try await store.archivedFootprints().map(\.workspace.name) == ["delta"])
    }

    @Test("the pages a delete frees come back to the file only after a compaction")
    func compactionReclaimsThePages() async throws {
        let store = try makeTestStore("archive-vacuum")
        let repo = try await store.upsert(Repo(name: "r", path: "/tmp/r"))
        let workspace = try await archive(store, repo: repo, name: "w", branch: "b")
        let session = try await store.upsert(Session(workspaceID: workspace.id, title: "S", model: "opus"))
        for index in 0..<200 {
            try await store.appendNext(
                sessionID: session.id, kind: .assistantText,
                payload: Data(String(repeating: "abcdefghij", count: 1_000).utf8)
                    + Data(String(index).utf8)
            )
        }

        let before = try await store.databaseSize()
        #expect(before.totalBytes > 2_000_000)

        try await store.deleteArchivedWorkspaces(ids: [workspace.id])

        let afterDelete = try await store.databaseSize()
        #expect(afterDelete.totalBytes == before.totalBytes)
        #expect(afterDelete.freeBytes > 1_500_000)

        try await store.compactDatabase()

        let afterCompaction = try await store.databaseSize()
        #expect(afterCompaction.freeBytes == 0)
        #expect(afterCompaction.totalBytes < before.totalBytes / 2)

        let onDisk = try FileManager.default
            .attributesOfItem(atPath: store.path)[.size] as? Int ?? 0
        #expect(onDisk < before.totalBytes / 2)
    }

    @Test("the total is what the rows hold between them")
    func totalsTheRows() {
        let cleanup = ArchiveCleanup(footprints: [
            footprint(name: "small", bytes: 10, archivedAt: 100),
            footprint(name: "huge", bytes: 10_000, archivedAt: 300),
            footprint(name: "middling", bytes: 500, archivedAt: 200),
        ])
        #expect(cleanup.totalBytes == 10_510)
        #expect(!cleanup.isEmpty)
        #expect(ArchiveCleanup(footprints: []).isEmpty)
    }

    @Test("the confirmation names what goes, counted and pluralised")
    func namesTheLosses() {
        let deletion = ArchiveDeletion([
            footprint(name: "port work", bytes: 1_500_000, archivedAt: 100, messages: 1, sessions: 1, comments: 1, note: true)
        ])
        #expect(deletion.title == "Delete everything Unified Dev kept about \u{201C}port work\u{201D}?")
        #expect(deletion.losses[0] == "1 transcript message across 1 chat, holding \(ArchiveDeletion.bytes(1_500_000))")
        #expect(deletion.losses[1] == "1 review comment written by hand")
        #expect(deletion.losses[2] == "a workspace note")
        #expect(deletion.confirmLabel == "Delete permanently")
        #expect(deletion.cancelLabel == "Keep the record")
    }

    @Test("several workspaces are counted rather than named")
    func countsSeveral() {
        let deletion = ArchiveDeletion([
            footprint(name: "a", bytes: 1_000, archivedAt: 1, messages: 4, sessions: 2),
            footprint(name: "b", bytes: 2_000, archivedAt: 2, messages: 6, sessions: 1),
        ])
        #expect(deletion.title == "Delete everything Unified Dev kept about 2 archived workspaces?")
        #expect(deletion.losses[0] == "10 transcript messages across 3 chats, holding \(ArchiveDeletion.bytes(3_000))")
        #expect(deletion.cancelLabel == "Keep the records")
    }

    @Test("nothing is claimed about a hand-written comment that is not there")
    func staysQuietAboutWhatIsAbsent() {
        let deletion = ArchiveDeletion([footprint(name: "a", bytes: 100, archivedAt: 1, messages: 2, sessions: 1)])
        #expect(deletion.losses.count == 1)
        #expect(!deletion.message.contains("review comment"))
        #expect(!deletion.message.contains("note"))
    }

    @Test("a branch still on this Mac reads differently from one that is not")
    func saysWhereTheBranchStands() {
        var kept = footprint(name: "a", bytes: 100, archivedAt: 1, branch: "feature/ports")
        kept.branchIsLocal = true
        #expect(ArchiveDeletion([kept]).branchStanding?.contains("still on this Mac") == true)
        #expect(ArchiveDeletion([kept]).branchStanding?.contains("feature/ports") == true)

        var gone = kept
        gone.branchIsLocal = false
        let standing = ArchiveDeletion([gone]).branchStanding
        #expect(standing?.contains("not on this Mac") == true)
        #expect(standing?.contains("last thing left") == true)
    }

    @Test("nothing is said about a branch nobody looked for")
    func staysQuietAboutAnUnknownBranch() {
        let unknown = footprint(name: "a", bytes: 100, archivedAt: 1)
        #expect(ArchiveDeletion([unknown]).branchStanding == nil)

        var one = footprint(name: "b", bytes: 100, archivedAt: 1)
        one.branchIsLocal = true
        #expect(ArchiveDeletion([unknown, one]).branchStanding == nil)
    }

    @Test("a mixed selection says how many of the branches are gone")
    func countsTheBranchesThatAreGone() {
        var kept = footprint(name: "a", bytes: 100, archivedAt: 1, id: "a")
        kept.branchIsLocal = true
        var gone = footprint(name: "b", bytes: 100, archivedAt: 1, id: "b")
        gone.branchIsLocal = false
        let standing = ArchiveDeletion([kept, gone]).branchStanding
        #expect(standing?.contains("1 of these 2 branches is no longer on this Mac") == true)
    }

    @Test("compaction is offered only when there is something worth reclaiming")
    func offersCompactionWhenItIsWorthIt() {
        let quiet = DatabaseSize(pageSize: 4_096, pageCount: 10_000, freePageCount: 10)
        #expect(!quiet.isWorthCompacting)

        let loaded = DatabaseSize(pageSize: 4_096, pageCount: 10_000, freePageCount: 4_000)
        #expect(loaded.isWorthCompacting)
        #expect(loaded.freeBytes == 16_384_000)
        #expect(loaded.usedBytes == 24_576_000)
    }

    @Test("what a record is made of reads as one line, and says nothing it was not told")
    func describesItsContents() {
        let bare = footprint(name: "a", bytes: 1_500_000, archivedAt: 1)
        #expect(bare.contents == ArchiveDeletion.bytes(1_500_000))

        var talkative = footprint(
            name: "b", bytes: 1_500_000, archivedAt: 1, messages: 312, sessions: 6
        )
        #expect(talkative.branchIsLocal == nil)
        #expect(
            talkative.contents
                == "\(ArchiveDeletion.bytes(1_500_000)) \u{00B7} 312 transcript messages in 6 chats"
        )

        talkative.branchIsLocal = true
        #expect(
            talkative.contents
                == "\(ArchiveDeletion.bytes(1_500_000)) \u{00B7} 312 transcript messages in 6 chats"
        )

        talkative.branchIsLocal = false
        #expect(talkative.contents.hasSuffix("\u{00B7} branch not on this Mac"))
    }

    @Test("the compaction offer says why the file is bigger than what is in it")
    func explainsCompaction() {
        let size = DatabaseSize(pageSize: 4_096, pageCount: 10_000, freePageCount: 4_000)
        #expect(size.compactionHelp.hasPrefix("\(ArchiveDeletion.bytes(16_384_000)) inside the database"))
        #expect(size.compactionHelp.contains("stops everything else while it runs"))
    }

    private func archive(
        _ store: Store, repo: Repo, name: String, branch: String
    ) async throws -> Workspace {
        var workspace = Workspace(
            repoID: repo.id, name: name, branch: branch,
            path: "/tmp/\(name)", baseBranch: "main"
        )
        _ = try await store.upsert(workspace)
        workspace.archive()
        workspace.archivedAt = Date()
        return try await store.upsert(workspace)
    }

    private func footprint(
        name: String,
        bytes: Int,
        archivedAt: TimeInterval,
        id: String = UUID().uuidString,
        branch: String = "b",
        messages: Int = 0,
        sessions: Int = 0,
        comments: Int = 0,
        note: Bool = false
    ) -> ArchivedWorkspaceFootprint {
        var workspace = Workspace(
            id: WorkspaceID(id), repoID: RepoID("r"), name: name, branch: branch,
            path: "/tmp/\(name)", baseBranch: "main"
        )
        workspace.archivedAt = Date(timeIntervalSince1970: archivedAt)
        return ArchivedWorkspaceFootprint(
            workspace: workspace,
            repoName: "r",
            sessionCount: sessions,
            messageCount: messages,
            transcriptBytes: bytes,
            otherBytes: 0,
            reviewCommentCount: comments,
            hasNote: note
        )
    }
}

@Suite("What a delete reports")
struct ArchiveDeletionOutcomeTests {
    @Test("a delete that worked says nothing, because the rows leaving is the report")
    func silentOnSuccess() {
        #expect(ArchiveDeletionOutcome.deleted(3).sentence == nil)
        #expect(ArchiveDeletionOutcome.deleted(3).didDelete)
    }

    @Test("deleting nothing is not a refusal")
    func zeroIsNotARefusal() {
        #expect(ArchiveDeletionOutcome.deleted(0).sentence == nil)
        #expect(!ArchiveDeletionOutcome.deleted(0).didDelete)
    }

    @Test("a refusal says what is safe, whether trying again helps, and quotes no SQL")
    func aRefusalIsASentence() throws {
        let outcome = ArchiveDeletionOutcome.refused(
            complaint: "database disk image is malformed."
        )
        let sentence = try #require(outcome.sentence)

        #expect(!outcome.didDelete)
        #expect(sentence.contains("they are all still here"))
        #expect(sentence.contains("No worktree and no branch was involved"))
        #expect(sentence.contains("refuse the next attempt the same way"))
        #expect(sentence.contains("The database said: database disk image is malformed."))
        #expect(!sentence.contains("DELETE"))
        #expect(!sentence.contains("?"))
    }

    @Test("a refusal reads as paragraphs, not one block")
    func theRefusalIsBrokenUp() throws {
        let sentence = try #require(
            ArchiveDeletionOutcome.refused(complaint: "database is malformed.").sentence
        )
        let paragraphs = sentence.components(separatedBy: "\n\n")
        #expect(paragraphs.count >= 3)
        for paragraph in paragraphs {
            #expect(!paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            #expect(!paragraph.contains("\n"))
        }
    }

    @Test("counts are grouped and pluralised the same way everywhere")
    func countsAgree() {
        #expect(ArchiveDeletion.count(1, "workspace") == "1 workspace")
        #expect(ArchiveDeletion.count(0, "workspace") == "0 workspaces")
        #expect(ArchiveDeletion.count(1_000, "workspace") != "1000 workspaces")
        #expect(ArchiveDeletion.count(1_000, "workspace").hasSuffix(" workspaces"))
    }
}
