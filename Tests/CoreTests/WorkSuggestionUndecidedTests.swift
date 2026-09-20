import Foundation
import Testing
@testable import Core

@Suite("Undecided suggested work", .tags(.persistence), .scratchDirectory)
struct WorkSuggestionUndecidedTests {
    private func plan(_ sql: String, _ bindings: [SQLValue] = [], in store: Store) throws -> [String] {
        let raw = try SQLiteDatabase(path: store.path)
        return try raw.query("EXPLAIN QUERY PLAN " + sql, bindings).compactMap { $0.string("detail") }
    }

    @Test("the undecided counts read an index holding only undecided rows, never the whole table")
    func countsReadTheUndecidedIndex() throws {
        let store = try makeTestStore("undecided-plan")

        let plans = [
            try plan(WorkSuggestionColumns.undecidedByWorkspace, in: store),
            try plan(WorkSuggestionColumns.undecidedInWorkspace, [.text("w")], in: store),
            try plan(WorkSuggestionColumns.undecidedInChat, [.text("s")], in: store),
        ]

        for steps in plans {
            #expect(steps.contains { $0.contains("work_suggestions_undecided") }, "\(steps)")
            #expect(!steps.contains { $0 == "SCAN work_suggestions" }, "\(steps)")
        }
    }

    @Test("a claim clears the reason an earlier start failed, so a released card shows no stale reason")
    func claimClearsAnOldFailure() async throws {
        let store = try makeTestStore("undecided-failure")
        let repo = try await store.upsert(Repo(name: "lantern", path: "/tmp/lantern", defaultBranch: "main"))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "Importer", branch: "importer", path: "/tmp/lantern-importer", baseBranch: "main"
        ))
        let chat = try await store.upsert(Session(workspaceID: workspace.id, title: "Import"))
        let admission = try await store.addWorkSuggestion(WorkSuggestion(
            workspaceID: workspace.id, sessionID: chat.id, title: "Keep the last row",
            why: "The parser drops the last row.", prompt: "Keep the last row.", target: .sameProject
        ))
        let suggestion = try #require(admission.suggestion)
        _ = try await store.claimWorkSuggestion(id: suggestion.id)
        try await store.releaseWorkSuggestion(id: suggestion.id, failure: "Too many workspaces are open.")

        let claimed = try await store.claimWorkSuggestion(id: suggestion.id)
        let released = try await store.releaseWorkSuggestionClaims()
        let read = try await store.workSuggestion(id: suggestion.id)

        guard case .claimed(let again) = claimed else { Issue.record("\(claimed)"); return }
        #expect(again.failure == nil)
        #expect(released == 1)
        #expect(read?.state == .pending)
        #expect(read?.failure == nil)
    }
}
