import Foundation
import Testing
@testable import Core

@Suite("Workspace diff tool at its edges", .tags(.git, .subprocess, .persistence), .scratchDirectory)
struct WorkspaceDiffToolEdgeTests {
    private struct Fixture {
        let store: Store
        let repo: TempRepo
        let workspace: Workspace
        let identity: BridgeIdentity
    }

    private func fixture(_ label: String, base: String = "main") async throws -> Fixture {
        let store = try makeTestStore(label)
        let repo = try await TempRepo()
        try repo.write("shared.txt", "one\n")
        try await repo.commit("shared")
        try await Shell.check("git", ["checkout", "-q", "-b", "feature"], cwd: repo.path)
        let project = try await store.upsert(Repo(name: "unifieddev", path: repo.path))
        let workspace = try await store.upsert(Workspace(
            repoID: project.id, name: "Feature", branch: "feature", path: repo.path, baseBranch: base
        ))
        let session = try await store.upsert(Session(workspaceID: workspace.id, title: "Chat"))
        let identity = BridgeIdentity(sessionID: session.id, workspaceID: workspace.id, role: .workspace)
        return Fixture(store: store, repo: repo, workspace: workspace, identity: identity)
    }

    private func call(_ f: Fixture, _ arguments: [String: JSONValue] = [:]) async -> BridgeToolResult {
        await WorkspaceDiffTool().call(
            MCPRequest(id: .integer(1), method: WorkspaceDiffTool.name, params: .object(arguments)),
            as: f.identity, store: f.store
        )
    }

    private func answer(_ f: Fixture, _ arguments: [String: JSONValue] = [:]) async throws -> JSONValue {
        let result = await call(f, arguments)
        #expect(!result.isError, "\(result.text)")
        return try #require(QuotedWorkspaceAnswer.json(result.text))
    }

    @Test("the budget passes small changes and names what is over it")
    func budget() {
        let small = [ChangedFile(path: "a", change: .modified, additions: 3, deletions: 1)]
        let long = [ChangedFile(path: "a", change: .modified, additions: 20_000, deletions: 1)]
        let many = (0...WorkspaceDiffBudget.untrackedLimit).map { ChangedFile(path: "f\($0)", change: .untracked) }

        #expect(WorkspaceDiffBudget.exceeded(by: small) == nil)
        #expect(WorkspaceDiffBudget.exceeded(by: long) == .tooManyLines(20_001))
        #expect(WorkspaceDiffBudget.exceeded(by: many) == .tooManyUntracked(201))
    }

    @Test("too many untracked files leaves the diff out, caps the list, and one path still reads")
    func manyUntracked() async throws {
        let f = try await fixture("diff-many")
        defer { f.repo.cleanUp() }
        for index in 0...WorkspaceDiffAnswer.fileListLimit {
            try f.repo.write(String(format: "loose/%03d.txt", index), "line \(index)\n")
        }

        let whole = try await answer(f)
        #expect(whole["diff"] == .string(""))
        #expect(whole["diff_omitted"]?.stringValue?.contains("untracked files") == true)
        #expect(whole["files"]?.arrayValue?.count == WorkspaceDiffAnswer.fileListLimit)
        #expect(whole["files_not_listed"] == .integer(1))
        #expect(whole["file_count"] == .integer(WorkspaceDiffAnswer.fileListLimit + 1))

        let one = try await answer(f, ["path": .string("loose/007.txt")])
        #expect(one["diff"]?.stringValue?.contains("+line 7") == true)
        #expect(one.objectValue?["diff_omitted"] == .null)
    }

    @Test("a file over the line budget is refused by path and leaves the whole diff out")
    func tooManyLines() async throws {
        let f = try await fixture("diff-long")
        defer { f.repo.cleanUp() }
        try f.repo.write("long.txt", String(repeating: "x\n", count: WorkspaceDiffBudget.lineLimit + 1))

        let whole = try await answer(f)
        #expect(whole["diff_omitted"]?.stringValue?.contains("lines added and removed") == true)

        let refused = await call(f, ["path": .string("long.txt")])
        #expect(refused.isError)
        #expect(refused.text.contains("more than the \(WorkspaceDiffBudget.lineLimit)"))
    }

    @Test("null is read as left out, and a path or cursor of the wrong type is refused")
    func argumentTypes() async throws {
        let f = try await fixture("diff-arguments")
        defer { f.repo.cleanUp() }
        try f.repo.write("shared.txt", "two\n")

        let nulls = try await answer(f, ["path": .null, "cursor": .null, "workspace": .null])
        #expect(nulls["diff"]?.stringValue?.contains("+two") == true)

        let number = await call(f, ["path": .integer(3)])
        #expect(number.text == WorkspaceDiffTrouble.pathNotText.sentence)
        let cursor = await call(f, ["cursor": .integer(3)])
        #expect(cursor.text == WorkspaceDiffTrouble.badCursor.sentence)
    }

    @Test("a cursor from another workspace is refused by the tool")
    func cursorFromElsewhere() async throws {
        let f = try await fixture("diff-foreign-cursor")
        defer { f.repo.cleanUp() }
        try f.repo.write("shared.txt", "two\n")

        let foreign = "w-elsewhere:\(WorkspaceDiffPage.fingerprint(diff: "", path: nil)):0"
        let refused = await call(f, ["cursor": .string(foreign)])

        #expect(refused.text == WorkspaceDiffTrouble.badCursor.sentence)
    }

    @Test("its own archived workspace is refused as its own")
    func ownArchived() async throws {
        let f = try await fixture("diff-own-archived")
        defer { f.repo.cleanUp() }
        try await f.store.update(workspaceID: f.workspace.id) { $0.archive() }

        let refused = await call(f)

        #expect(refused.text == BridgeReadTrouble.callerArchived.sentence(tool: WorkspaceDiffTool.name))
    }

    @Test("a path names the file that has it before a rename that left it")
    func exactPathFirst() async throws {
        let f = try await fixture("diff-exact")
        defer { f.repo.cleanUp() }
        try f.repo.write("z.txt", "zed\nzed\nzed\n")
        try await f.repo.commit("z on feature")
        try await Shell.check("git", ["branch", "-f", "main", "HEAD"], cwd: f.repo.path)
        try await Shell.check("git", ["mv", "z.txt", "b.txt"], cwd: f.repo.path)
        try f.repo.write("z.txt", "new zed\n")

        let fresh = try await answer(f, ["path": .string("z.txt")])
        let files = try #require(fresh["files"]?.arrayValue)
        #expect(files.map { $0["path"] } == [.string("z.txt")])
        #expect(fresh["diff"]?.stringValue?.contains("+new zed") == true)
    }

    @Test("a base git cannot find is refused in a sentence, and no changes say so")
    func missingBaseAndNothing() async throws {
        let broken = try await fixture("diff-no-base", base: "nowhere")
        defer { broken.repo.cleanUp() }
        let refused = await call(broken)
        #expect(refused.isError)
        #expect(refused.text.contains("could not read the changes"))

        let clean = try await fixture("diff-clean")
        defer { clean.repo.cleanUp() }
        let nothing = try await answer(clean)
        #expect(nothing["note"]?.stringValue?.contains("has no changes") == true)
        #expect(nothing["files"]?.arrayValue?.isEmpty == true)
    }
}
