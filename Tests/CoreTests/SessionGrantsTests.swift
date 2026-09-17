import Foundation
import Testing
@testable import Core

@Suite("Session grants", .tags(.persistence), .scratchDirectory)
struct SessionGrantsTests {
    private static func ask(tool: String = "Bash", rule: String? = "bin/test:*") -> PermissionAsk {
        let rules: [PermissionRule] = rule.map { [PermissionRule(toolName: tool, ruleContent: $0)] } ?? []
        return PermissionAsk(
            requestID: "req-1",
            toolName: tool,
            input: .object(["command": .string("bin/test --filter Permission")]),
            suggestions: rules.isEmpty ? [] : [PermissionSuggestion(
                type: "addRules",
                behavior: "allow",
                destination: "localSettings",
                rules: rules,
                raw: .object([:])
            )]
        )
    }

    private static func project(_ store: Store) async throws -> (repo: Repo, workspace: Workspace) {
        let repo = try await store.upsert(Repo(name: "Unified Dev", path: "/tmp/unifieddev-\(newID())"))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "w", branch: "b", path: "/tmp/w-\(newID())", baseBranch: "main"
        ))
        return (repo, workspace)
    }

    @Test("the repo behind a chat is found from its workspace")
    func resolvesTheRepo() async throws {
        let store = try makeTestStore()
        let (repo, workspace) = try await Self.project(store)
        let grants = SessionGrants(store: store, workspaceID: workspace.id)

        #expect(await grants.repoID() == repo.id)
        #expect(await grants.repoID() == repo.id)
    }

    @Test("a chat with no worktree has no project to grant in")
    func chatWithNoWorkspace() async throws {
        let store = try makeTestStore()
        let grants = SessionGrants(store: store, workspaceID: nil)

        #expect(await grants.repoID() == nil)
        #expect(await grants.matching(Self.ask()) == nil)

        await grants.record(.allow(scope: .project), from: Self.ask())
        #expect(try await store.permissionGrants().isEmpty)
    }

    @Test("a stored rule answers the next question in the same project")
    func matchesAStoredRule() async throws {
        let store = try makeTestStore()
        let (repo, workspace) = try await Self.project(store)
        try await store.upsert(PermissionGrant.granting(
            PermissionRule(toolName: "Bash", ruleContent: "bin/test:*"), repoID: repo.id
        ))
        let grants = SessionGrants(store: store, workspaceID: workspace.id)

        let matched = try #require(await grants.matching(Self.ask()))
        #expect(matched.count == 1)
        #expect(matched[0].displayText == "Bash(bin/test:*)")
    }

    @Test("a rule granted in one project does not answer in another")
    func doesNotCrossProjects() async throws {
        let store = try makeTestStore()
        let (repo, _) = try await Self.project(store)
        let (_, elsewhere) = try await Self.project(store)
        try await store.upsert(PermissionGrant.granting(
            PermissionRule(toolName: "Bash", ruleContent: "bin/test:*"), repoID: repo.id
        ))

        let grants = SessionGrants(store: store, workspaceID: elsewhere.id)
        #expect(await grants.matching(Self.ask()) == nil)
    }

    @Test("a project decision is written down, and a once-only one is not")
    func recordsOnlyProjectScope() async throws {
        let store = try makeTestStore()
        let (repo, workspace) = try await Self.project(store)
        let grants = SessionGrants(store: store, workspaceID: workspace.id)

        await grants.record(.allow(scope: .once), from: Self.ask())
        #expect(try await store.permissionGrants(repoID: repo.id).isEmpty)

        await grants.record(.allow(scope: .project), from: Self.ask())
        let stored = try await store.permissionGrants(repoID: repo.id)
        #expect(stored.count == 1)
        #expect(stored[0].displayText == "Bash(bin/test:*)")

        #expect(await grants.matching(Self.ask()) != nil)
    }

    @Test("using a grant to answer a question counts the use")
    func countsUses() async throws {
        let store = try makeTestStore()
        let (repo, workspace) = try await Self.project(store)
        let grant = try await store.upsert(PermissionGrant.granting(
            PermissionRule(toolName: "Bash", ruleContent: "bin/test:*"), repoID: repo.id
        ))
        let grants = SessionGrants(store: store, workspaceID: workspace.id)

        await grants.recordUse(of: [grant])
        await grants.recordUse(of: [grant])

        let stored = try #require(await store.permissionGrants(repoID: repo.id).first)
        #expect(stored.useCount == 2)
        #expect(stored.lastUsedAt != nil)
    }

    @Test("a revoked rule stops answering immediately")
    func revocationIsImmediate() async throws {
        let store = try makeTestStore()
        let (repo, workspace) = try await Self.project(store)
        let grant = try await store.upsert(PermissionGrant.granting(
            PermissionRule(toolName: "Bash", ruleContent: "bin/test:*"), repoID: repo.id
        ))
        let grants = SessionGrants(store: store, workspaceID: workspace.id)
        #expect(await grants.matching(Self.ask()) != nil)

        try await store.deletePermissionGrant(id: grant.id)

        #expect(await grants.matching(Self.ask()) == nil)
    }

    @Test("an ask that cannot be widened is never answered from a grant")
    func neverAnswersAnAskThatCannotWiden() async throws {
        let store = try makeTestStore()
        let (repo, workspace) = try await Self.project(store)
        try await store.upsert(PermissionGrant.granting(
            PermissionRule(toolName: "Bash", ruleContent: "bin/test:*"), repoID: repo.id
        ))
        let grants = SessionGrants(store: store, workspaceID: workspace.id)

        var ask = Self.ask()
        ask.suppressesAlwaysAllow = true
        #expect(await grants.matching(ask) == nil)
    }
}
