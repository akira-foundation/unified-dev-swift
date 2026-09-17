import Testing
import Foundation
@testable import Core

private let liveEnabled = ProcessInfo.processInfo.environment["UD_LIVE"] == "1"

@Suite("LiveReview", .enabled(if: liveEnabled), .tags(.subprocess), .scratchDirectory)
struct LiveReviewTests {
    @Test("two comments on two files are both understood and both fixed", .timeLimit(.minutes(5)))
    func twoCommentTurn() async throws {
        let repo = try await TempRepo()
        try repo.write("greeter.py", "def greet(name):\n    print(\"Hi\")\n")
        try repo.write("farewell.py", "def farewell(name):\n    print(\"Bye\")\n")
        try await repo.commit("base")
        defer { repo.cleanUp() }

        let store = try makeTestStore("livereview")
        let manager = WorkspaceManager(store: store)
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Review check")
        let session = try await store.upsert(Session(
            workspaceID: workspace.id,
            model: "haiku",
            permissionMode: .bypassPermissions
        ))

        let worktree = TempRepo(existing: workspace.path)
        try worktree.write("greeter.py", "def greet(name):\n    print(\"Hello \" + name)\n")
        try worktree.write(
            "farewell.py", "def farewell(name):\n    print(\"Goodby, \" + name)\n"
        )

        let comments = [
            ReviewComment(
                workspaceID: workspace.id,
                filePath: "greeter.py",
                anchor: ReviewCommentAnchor.make(
                    line: 2, in: ReviewCommentAnchor.split(worktree.read("greeter.py") ?? "")
                ),
                body: "Use an f-string here instead of string concatenation."
            ),
            ReviewComment(
                workspaceID: workspace.id,
                filePath: "farewell.py",
                anchor: ReviewCommentAnchor.make(
                    line: 2, in: ReviewCommentAnchor.split(worktree.read("farewell.py") ?? "")
                ),
                body: "There is a typo in this string: Goodby should be Goodbye. Fix only the typo."
            ),
        ]

        let composed = ReviewTurn.compose(
            message: "Please address both review comments.",
            comments: comments,
            worktreePath: workspace.path,
            template: PromptRegistry.definition(for: .review).defaultTemplate
        )
        print("=== composed review turn ===\n\(composed)\n=== end composed turn ===")

        let record = try #require(ReviewTurn.split(composed))
        #expect(record.chips.count == 2)

        let runner = AgentRunner(workspacePath: workspace.path, session: session, store: store)
        let collected = EventLog()
        let pump = Task { for await event in runner.events { collected.record(event) } }
        try await runner.send(composed)

        let deadline = Date().addingTimeInterval(240)
        while !collected.sawResult, Date() < deadline {
            try await Task.sleep(for: .milliseconds(200))
        }
        pump.cancel()
        #expect(collected.sawResult, "the agent never emitted a result event")
        print("=== agent result ===\n\(collected.resultSummary)\n=== end result ===")

        let greeter = try #require(worktree.read("greeter.py"))
        let farewell = try #require(worktree.read("farewell.py"))
        print("=== greeter.py after ===\n\(greeter)=== farewell.py after ===\n\(farewell)===")

        #expect(
            greeter.contains("f\"") || greeter.contains("f'"),
            "greeter.py was not moved to an f-string"
        )
        #expect(farewell.contains("Goodbye"), "the farewell typo was not fixed")

        #expect(greeter.hasPrefix("def greet(name):\n"))
        #expect(farewell.hasPrefix("def farewell(name):\n"))
        #expect(!greeter.contains("Goodbye"))
    }
}
