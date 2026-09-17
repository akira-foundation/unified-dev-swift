import Foundation
import Testing
@testable import Core

@Suite("Permission grants", .tags(.persistence), .scratchDirectory)
struct PermissionGrantTests {
    static func ask(
        tool: String = "Bash",
        rule: String? = "bin/test:*",
        suppressed: Bool = false,
        needsInteraction: Bool = false
    ) -> PermissionAsk {
        let rules: [PermissionRule] = rule.map { [PermissionRule(toolName: tool, ruleContent: $0)] } ?? []
        let suggestion = PermissionSuggestion(
            type: "addRules",
            behavior: "allow",
            destination: "localSettings",
            rules: rules,
            raw: .object([:])
        )
        return PermissionAsk(
            requestID: "req-1",
            toolName: tool,
            input: .object(["command": .string("bin/test --filter Permission")]),
            suggestions: rules.isEmpty ? [] : [suggestion],
            suppressesAlwaysAllow: suppressed,
            requiresUserInteraction: needsInteraction
        )
    }

    static func grant(tool: String = "Bash", rule: String? = "bin/test:*") -> PermissionGrant {
        PermissionGrant(repoID: RepoID("repo-1"), toolName: tool, ruleContent: rule)
    }

    @Test("the same rule, stored, answers the question")
    func exactMatch() {
        let matched = PermissionGrantIndex.match(ask: Self.ask(), grants: [Self.grant()])

        #expect(matched?.count == 1)
        #expect(matched?.first?.displayText == "Bash(bin/test:*)")
    }

    @Test("nothing stored means somebody has to answer")
    func noGrants() {
        #expect(PermissionGrantIndex.match(ask: Self.ask(), grants: []) == nil)
    }

    @Test("a wildcard rule the CLI composed matches by being the same string")
    func wildcardIsJustAString() {
        let first = Self.ask(rule: "bin/test:*")
        let second = PermissionAsk(
            requestID: "req-2",
            toolName: "Bash",
            input: .object(["command": .string("bin/test --filter Something Else")]),
            suggestions: [PermissionSuggestion(
                type: "addRules",
                behavior: "allow",
                rules: [PermissionRule(toolName: "Bash", ruleContent: "bin/test:*")]
            )]
        )
        let grants = [Self.grant(rule: "bin/test:*")]

        #expect(PermissionGrantIndex.match(ask: first, grants: grants) != nil)
        #expect(PermissionGrantIndex.match(ask: second, grants: grants) != nil)
    }

    @Test(
        "a rule that is not the same string is not the same rule",
        arguments: [
            "bin/test",          // the stored rule without its wildcard
            "bin/test:",         // a truncation
            "bin/test:**",       // a wider wildcard
            "Bin/Test:*",        // different case
            " bin/test:*",       // leading space
            "bin/test:* ",       // trailing space
            "./bin/test:*",      // the same path said differently
            "bin/test:*;rm -rf", // the stored rule as a prefix of a longer one
        ]
    )
    func neverWidens(stored: String) {
        let matched = PermissionGrantIndex.match(ask: Self.ask(rule: "bin/test:*"), grants: [Self.grant(rule: stored)])

        #expect(matched == nil, "\(stored) was treated as Bash(bin/test:*)")
    }

    @Test("a grant for one tool never answers for another")
    func toolNamesMustMatch() {
        let matched = PermissionGrantIndex.match(
            ask: Self.ask(tool: "Bash", rule: "bin/test:*"),
            grants: [Self.grant(tool: "Edit", rule: "bin/test:*")]
        )

        #expect(matched == nil)
    }

    @Test("every rule in the suggestion has to be covered, not just one")
    func allRulesOrNone() {
        let ask = PermissionAsk(
            requestID: "req-1",
            toolName: "Bash",
            suggestions: [PermissionSuggestion(
                type: "addRules",
                behavior: "allow",
                rules: [
                    PermissionRule(toolName: "Bash", ruleContent: "bin/test:*"),
                    PermissionRule(toolName: "Bash", ruleContent: "bin/lint:*"),
                ]
            )]
        )

        #expect(PermissionGrantIndex.match(ask: ask, grants: [Self.grant(rule: "bin/test:*")]) == nil)
        #expect(PermissionGrantIndex.match(ask: ask, grants: [
            Self.grant(rule: "bin/test:*"),
            Self.grant(rule: "bin/lint:*"),
        ])?.count == 2)
    }

    @Test("an ask the CLI marked unwidenable is never answered from a stored rule")
    func respectsTheCLIFlags() {
        let grants = [Self.grant()]

        #expect(PermissionGrantIndex.match(ask: Self.ask(suppressed: true), grants: grants) == nil)
        #expect(PermissionGrantIndex.match(ask: Self.ask(needsInteraction: true), grants: grants) == nil)
        #expect(PermissionGrantIndex.match(ask: Self.ask(rule: nil), grants: grants) == nil)
    }

    @Test("an auto-allowed call says which rule allowed it")
    func note() {
        let note = PermissionGrantIndex.note(for: [Self.grant()])

        #expect(note.contains("Bash(bin/test:*)"))
        #expect(note.contains("you approved"))
    }

    @Test("a grant survives a round trip and is listed per project")
    func stored() async throws {
        let store = try makeTestStore()
        let repo = try await store.upsert(Repo(name: "Unified Dev", path: "/tmp/unifieddev-\(newID())"))

        let grant = try await store.upsert(PermissionGrant.granting(
            PermissionRule(toolName: "Bash", ruleContent: "bin/test:*"),
            repoID: repo.id,
            for: "bin/test --filter Permission"
        ))

        let listed = try await store.permissionGrants(repoID: repo.id)
        #expect(listed.count == 1)
        #expect(listed.first?.displayText == "Bash(bin/test:*)")
        #expect(listed.first?.grantedFor == "bin/test --filter Permission")
        #expect(listed.first?.id == grant.id)
    }

    @Test("granting the same rule twice keeps the first grant")
    func grantingTwiceIsIdempotent() async throws {
        let store = try makeTestStore()
        let repo = try await store.upsert(Repo(name: "Unified Dev", path: "/tmp/unifieddev-\(newID())"))
        let rule = PermissionRule(toolName: "Bash", ruleContent: "bin/test:*")

        let first = try await store.upsert(PermissionGrant.granting(rule, repoID: repo.id))
        try await store.recordPermissionGrantUse(id: first.id)
        let second = try await store.upsert(PermissionGrant.granting(rule, repoID: repo.id))

        #expect(second.id == first.id)
        #expect(second.useCount == 1)
        #expect(try await store.permissionGrants(repoID: repo.id).count == 1)
    }

    @Test("a whole-tool grant is stored once and reads back as having no content")
    func wholeToolGrant() async throws {
        let store = try makeTestStore()
        let repo = try await store.upsert(Repo(name: "Unified Dev", path: "/tmp/unifieddev-\(newID())"))
        let rule = PermissionRule(toolName: "WebFetch", ruleContent: nil)

        try await store.upsert(PermissionGrant.granting(rule, repoID: repo.id))
        try await store.upsert(PermissionGrant.granting(rule, repoID: repo.id))

        let listed = try await store.permissionGrants(repoID: repo.id)
        #expect(listed.count == 1)
        #expect(listed.first?.ruleContent == nil)
        #expect(listed.first?.displayText == "WebFetch")
        #expect(listed.first?.rule == rule)
    }

    @Test("counting a use does not change what was granted")
    func recordingUse() async throws {
        let store = try makeTestStore()
        let repo = try await store.upsert(Repo(name: "Unified Dev", path: "/tmp/unifieddev-\(newID())"))
        let grant = try await store.upsert(PermissionGrant.granting(
            PermissionRule(toolName: "Bash", ruleContent: "swift build:*"),
            repoID: repo.id
        ))

        try await store.recordPermissionGrantUse(id: grant.id)
        try await store.recordPermissionGrantUse(id: grant.id)

        let stored = try #require(await store.permissionGrants(repoID: repo.id).first)
        #expect(stored.useCount == 2)
        #expect(stored.lastUsedAt != nil)
        #expect(stored.rule == grant.rule)
    }

    @Test("a revoked rule stops matching immediately")
    func revocationIsImmediate() async throws {
        let store = try makeTestStore()
        let repo = try await store.upsert(Repo(name: "Unified Dev", path: "/tmp/unifieddev-\(newID())"))
        let grant = try await store.upsert(PermissionGrant.granting(
            PermissionRule(toolName: "Bash", ruleContent: "bin/test:*"),
            repoID: repo.id
        ))
        let ask = Self.ask()

        #expect(PermissionGrantIndex.match(ask: ask, grants: try await store.permissionGrants(repoID: repo.id)) != nil)

        try await store.deletePermissionGrant(id: grant.id)

        #expect(PermissionGrantIndex.match(ask: ask, grants: try await store.permissionGrants(repoID: repo.id)) == nil)
    }

    @Test("a grant in one project never answers for another")
    func grantsAreScopedToTheirProject() async throws {
        let store = try makeTestStore()
        let unifieddev = try await store.upsert(Repo(name: "Unified Dev", path: "/tmp/unifieddev-\(newID())"))
        let ember = try await store.upsert(Repo(name: "Ember", path: "/tmp/ember-\(newID())"))
        try await store.upsert(PermissionGrant.granting(
            PermissionRule(toolName: "Bash", ruleContent: "bin/test:*"),
            repoID: unifieddev.id
        ))

        #expect(try await store.permissionGrants(repoID: ember.id).isEmpty)
        #expect(try await store.permissionGrants(repoID: unifieddev.id).count == 1)
        #expect(try await store.permissionGrants().count == 2 - 1)
    }

    @Test("a project going away takes its grants with it")
    func cascades() async throws {
        let store = try makeTestStore()
        let repo = try await store.upsert(Repo(name: "Unified Dev", path: "/tmp/unifieddev-\(newID())"))
        try await store.upsert(PermissionGrant.granting(
            PermissionRule(toolName: "Bash", ruleContent: "bin/test:*"),
            repoID: repo.id
        ))

        try await store.deleteRepo(id: repo.id)

        #expect(try await store.permissionGrants().isEmpty)
    }
}

@Suite("Pending permission asks", .tags(.persistence), .scratchDirectory)
struct PendingPermissionAskTests {
    private func session(in store: Store, label: String = "s") async throws -> Session {
        let repo = try await store.upsert(Repo(name: "r-\(label)", path: "/tmp/r-\(label)-\(newID())"))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: label, branch: "b", path: "/tmp/w-\(label)", baseBranch: "main"
        ))
        return try await store.upsert(Session(workspaceID: workspace.id))
    }

    private var realAsk: PermissionAsk {
        PermissionAsk.decode(payload: Data(PermissionAskTests.realAsk.utf8))!
    }

    @Test("a pending ask comes back whole, with its question intact")
    func roundTrips() async throws {
        let store = try makeTestStore()
        let session = try await session(in: store)
        let ask = realAsk

        try await store.appendPermissionAsk(sessionID: session.id, ask: ask)

        let pending = try await store.pendingPermissionAsks(sessionID: session.id)
        #expect(pending.count == 1)
        #expect(pending.first?.ask == ask)
        #expect(pending.first?.ask.subject == "sudo -n true")
        #expect(pending.first?.ask.ruleText == "Bash(sudo -n true)")
    }

    @Test("answering it takes it out of the pending list and records what was said")
    func resolving() async throws {
        let store = try makeTestStore()
        let session = try await session(in: store)
        let ask = realAsk
        try await store.appendPermissionAsk(sessionID: session.id, ask: ask)

        try await store.resolvePermissionAsk(
            id: ask.requestID,
            decision: PermissionDecision.allow(scope: .project).storedName
        )

        #expect(try await store.pendingPermissionAsks(sessionID: session.id).isEmpty)
        #expect(try await store.permissionAskDecisions(sessionID: session.id)[ask.requestID] == "allow-project")
    }

    @Test("the same request id filed twice is one question")
    func idempotent() async throws {
        let store = try makeTestStore()
        let session = try await session(in: store)
        let ask = realAsk

        try await store.appendPermissionAsk(sessionID: session.id, ask: ask)
        try await store.appendPermissionAsk(sessionID: session.id, ask: ask)

        #expect(try await store.pendingPermissionAsks(sessionID: session.id).count == 1)
    }

    @Test("answering twice does not overwrite the first answer")
    func resolvingIsOnce() async throws {
        let store = try makeTestStore()
        let session = try await session(in: store)
        let ask = realAsk
        try await store.appendPermissionAsk(sessionID: session.id, ask: ask)

        try await store.resolvePermissionAsk(id: ask.requestID, decision: "allow-once")
        try await store.resolvePermissionAsk(id: ask.requestID, decision: "deny")

        #expect(try await store.permissionAskDecisions(sessionID: session.id)[ask.requestID] == "allow-once")
    }

    @Test("a question nobody can answer any more is closed at launch")
    func abandoning() async throws {
        let store = try makeTestStore()
        let session = try await session(in: store)
        let ask = realAsk
        try await store.appendPermissionAsk(sessionID: session.id, ask: ask)

        let closed = try await store.abandonPendingPermissionAsks()

        #expect(closed == 1)
        #expect(try await store.pendingPermissionAsks().isEmpty)

        let decision = try #require(await store.permissionAskDecisions(sessionID: session.id)[ask.requestID])
        #expect(decision == PermissionAskOutcome.abandoned)
        #expect(PermissionAskOutcome.wentUnanswered(decision))
        #expect(!PermissionAskOutcome.summary(decision).isEmpty)
        #expect(PermissionAskOutcome.advice(decision).contains("worktree still holds"))
    }

    @Test("a launch after a crash clears the session and the question together")
    func launchAfterACrash() async throws {
        let store = try makeTestStore()
        let session = try await session(in: store)
        try await store.appendPermissionAsk(sessionID: session.id, ask: realAsk)
        try await store.update(sessionID: session.id) { $0.state = .waiting }

        try await store.resetRunningSessions()
        let abandoned = try await store.abandonPendingPermissionAsks()

        #expect(abandoned == 1)
        #expect(try await store.session(id: session.id)?.state == .idle)
        #expect(try await store.pendingPermissionAsks().isEmpty)
    }

    @Test("every blocked session is found in one query")
    func acrossSessions() async throws {
        let store = try makeTestStore()
        let first = try await session(in: store, label: "one")
        let second = try await session(in: store, label: "two")
        let third = try await session(in: store, label: "three")

        try await store.appendPermissionAsk(sessionID: first.id, ask: realAsk)
        let other = try #require(PermissionAsk.decode(payload: Data(
            PermissionAskTests.realAsk
                .replacingOccurrences(of: "2f9899b1-849f-4d1b-b4b2-9c6e1304b300", with: "second-request")
                .utf8
        )))
        try await store.appendPermissionAsk(sessionID: second.id, ask: other)

        let pending = try await store.pendingPermissionAsks()
        #expect(pending.count == 2)
        #expect(Set(pending.map(\.sessionID)) == [first.id, second.id])
        #expect(!pending.map(\.sessionID).contains(third.id))
    }

    @Test("a session going away takes its questions with it")
    func cascades() async throws {
        let store = try makeTestStore()
        let session = try await session(in: store)
        try await store.appendPermissionAsk(sessionID: session.id, ask: realAsk)

        try await store.deleteSession(id: session.id)

        #expect(try await store.pendingPermissionAsks().isEmpty)
    }

    @Test("bytes that will not decode are skipped rather than drawn empty")
    func unreadablePayload() async throws {
        let store = try makeTestStore()
        let session = try await session(in: store)
        try await store.appendPermissionAsk(
            sessionID: session.id,
            ask: PermissionAsk(requestID: "broken", toolName: "Bash", raw: Data("not json".utf8))
        )
        try await store.appendPermissionAsk(sessionID: session.id, ask: realAsk)

        let pending = try await store.pendingPermissionAsks(sessionID: session.id)
        #expect(pending.count == 1)
        #expect(pending.first?.requestID == realAsk.requestID)
    }
}

@Suite("Permission grants: what a decision stores")
struct PermissionGrantWritingTests {
    private let repoID = RepoID(rawValue: "repo-1")

    private func ask(rules: [PermissionRule]) -> PermissionAsk {
        PermissionAsk(
            requestID: "req-1",
            toolName: "Bash",
            input: .object(["command": .string("ls")]),
            suggestions: [
                PermissionSuggestion(type: "addRules", behavior: "allow", rules: rules, raw: .object([:]))
            ]
        )
    }

    @Test("a project allow writes one grant per rule, credited to what was asked about")
    func projectAllowWritesEveryRule() {
        let grants = PermissionGrant.all(
            granting: .allow(scope: .project),
            from: ask(rules: [
                PermissionRule(toolName: "Bash", ruleContent: "ls"),
                PermissionRule(toolName: "Bash", ruleContent: "git status"),
            ]),
            repoID: repoID
        )

        #expect(grants.count == 2)
        #expect(grants.map(\.ruleContent) == ["ls", "git status"])
        #expect(grants.allSatisfy { $0.repoID == repoID })
        #expect(grants.allSatisfy { $0.grantedFor == "ls" })
    }

    @Test("nothing narrower than project scope is remembered")
    func narrowerScopesStoreNothing() {
        let question = ask(rules: [PermissionRule(toolName: "Bash", ruleContent: "ls")])

        #expect(PermissionGrant.all(granting: .allow(scope: .once), from: question, repoID: repoID).isEmpty)
        #expect(PermissionGrant.all(granting: .allow(scope: .session), from: question, repoID: repoID).isEmpty)
        #expect(
            PermissionGrant.all(
                granting: .deny(message: "no", endsTurn: false), from: question, repoID: repoID
            ).isEmpty
        )
        #expect(
            PermissionGrant.all(granting: .answer(input: .object([:])), from: question, repoID: repoID)
                .isEmpty
        )
    }

    @Test("an ask carrying no rules stores nothing, even on a project allow")
    func nothingOfferedIsNothingStored() {
        #expect(
            PermissionGrant.all(granting: .allow(scope: .project), from: ask(rules: []), repoID: repoID)
                .isEmpty
        )
    }
}
