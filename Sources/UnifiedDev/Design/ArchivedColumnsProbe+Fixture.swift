import AppKit
import Core

extension ArchivedColumnsProbe {
    struct Fixture {
        var archived: Workspace
        var live: Workspace
    }
    static func makeFixture(
        app: AppModel, store: Store, at root: URL, record: (Repo) -> Void
    ) async throws -> Fixture {
        let repoPath = root.appendingPathComponent("atlas").path
        try FileManager.default.createDirectory(atPath: repoPath, withIntermediateDirectories: true)
        try await Shell.check("git", ["init", "-q", "-b", "main"], cwd: repoPath)
        try await Shell.check("git", Self.author + ["commit", "--allow-empty", "-qm", "Draw the first map"], cwd: repoPath)

        let repo = try await store.upsert(Repo(name: "Archived columns probe", path: repoPath))
        record(repo)
        let archived = try await worktree(
            "Test run", branch: "test-run", in: repo, at: root, store: store
        )
        let live = try await worktree(
            "Dinghy", branch: "dinghy", in: repo, at: root, store: store
        )
        let session = try await store.upsert(Session(workspaceID: archived.id, title: "Only chat"))
        _ = try await store.appendNext(
            sessionID: session.id, kind: .user,
            payload: try line("What happens when I click this?", role: "user")
        )
        _ = try await store.appendNext(
            sessionID: session.id, kind: .assistantText,
            payload: try line("The archive card, the button and this transcript.", role: "assistant")
        )
        await app.reload()

        await app.archive(archived, deleteBranch: false)
        if let request = app.pendingArchive { await app.confirmArchive(request) }
        for _ in 0..<200 where try await store.workspace(id: archived.id)?.state != .archived {
            try? await Task.sleep(for: .milliseconds(100))
        }
        await app.reload()
        return Fixture(archived: archived, live: live)
    }
    static func worktree(
        _ name: String, branch: String, in repo: Repo, at root: URL, store: Store
    ) async throws -> Workspace {
        let path = root.appendingPathComponent(branch).path
        try await Shell.check("git", ["worktree", "add", "-qb", branch, path], cwd: repo.path)
        return try await store.upsert(Workspace(
            repoID: repo.id, name: name, branch: branch, path: path, baseBranch: "main"
        ))
    }
    static func line(_ text: String, role: String) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "type": role,
                "message": ["role": role, "content": [["type": "text", "text": text]]],
            ],
            options: [.sortedKeys]
        )
    }
    static let author = [
        "-c", "user.name=Archived Columns Probe",
        "-c", "user.email=probe@unifieddev.invalid",
        "-c", "commit.gpgsign=false",
    ]
}
