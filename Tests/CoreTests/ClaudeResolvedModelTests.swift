import Foundation
import Testing
@testable import Core

@Suite("The version an alias of Claude Code really runs", .tags(.agentProtocol), .scratchDirectory)
struct ClaudeResolvedModelTests {
    private let work = AgentAccountHome(
        provider: .claudeCode, id: AgentAccountID("work"),
        directory: URL(filePath: "/accounts/claudeCode/work"), isDefault: false
    )
    private let client = AgentAccountHome(
        provider: .claudeCode, id: AgentAccountID("client"),
        directory: URL(filePath: "/accounts/claudeCode/client"), isDefault: false
    )

    private func model(_ id: String, unavailable: String? = nil) -> AgentModel {
        AgentModel(id: id, displayName: id, unavailable: unavailable)
    }

    private func version(listed: [AgentModel] = [], observed: [String: String] = [:]) -> String? {
        ClaudeResolvedModel.version(ofAlias: "opus", listed: listed, observed: observed)
    }

    @Test("the account's own list names the version of its family")
    func readsTheAccountList() {
        #expect(ClaudeResolvedModel.version(
            ofAlias: "fable", listed: [model("claude-fable-5-1[1m]")], observed: [:]
        ) == "5.1")
    }

    @Test("the list outranks what was observed, and the newest listed entry outranks an older one")
    func theListComesFirst() {
        let listed = [model("claude-opus-5-1"), model("claude-opus-5-5")]

        #expect(version(listed: listed, observed: ["opus": "claude-opus-4-8"]) == "5.5")
    }

    @Test("what the CLI reported answers when the list says nothing about the family")
    func fallsBackToTheObservation() {
        #expect(version(listed: [model("claude-fable-5-1")], observed: ["opus": "claude-opus-5-5"]) == "5.5")
    }

    @Test("a dated id of a whole version does not outrank a newer point release")
    func aDateIsNotAMinorVersion() {
        let listed = [model("claude-opus-4-20250514"), model("claude-opus-4-5-20250929")]

        #expect(version(listed: listed) == "4.5")
    }

    @Test("an entry the account cannot use never names a version", arguments: [
        "claude-opus-5-5", "cc-update-required-1",
    ])
    func refusesAnUnusableEntry(id: String) {
        #expect(version(listed: [model(id, unavailable: "Update first")]) == nil)
    }

    @Test("an alias that resolved to another family has no version of its own")
    func refusesAnotherFamily() {
        #expect(version(observed: ["opus": "claude-sonnet-5"]) == nil)
    }

    @Test("with no source there is no version")
    func saysNothingWithoutASource() {
        #expect(version() == nil)
    }

    @Test("reads a version out of every shape of id", arguments: [
        ("claude-opus-5", "5"),
        ("claude-opus-5-5", "5.5"),
        ("claude-opus-5-5[1m]", "5.5"),
        ("claude-opus-4-8-20260101", "4.8"),
        ("claude-opus-5-20260101", "5"),
    ])
    func readsTheVersion(id: String, expected: String) {
        #expect(ClaudeResolvedModel.version(of: id, alias: "opus") == expected)
    }

    @Test("an id that names no version answers nothing", arguments: [
        "opus", "opus-5-5", "claude-opus", "claude-3-opus-20240229",
    ])
    func readsNoVersion(id: String) {
        #expect(ClaudeResolvedModel.version(of: id, alias: "opus") == nil)
    }

    @Test("the picker keeps the alias as its id and adds the version to the name")
    func offersTheAliasWithItsVersion() {
        let offered = ClaudeModelCatalog.offered(
            read: [model("claude-fable-5-1[1m]")],
            observed: ["opus": "claude-opus-5-5"]
        )

        let names = Dictionary(uniqueKeysWithValues: offered.map { ($0.id, $0.displayName) })
        #expect(names["fable"] == "Fable 5.1")
        #expect(names["opus"] == "Opus 5.5")
        #expect(names["sonnet"] == "Sonnet")
        #expect(names["haiku"] == "Haiku")
    }

    @Test("offering an already offered list keeps one row per alias, and its version")
    func offeringTwiceKeepsTheVersion() {
        let first = ClaudeModelCatalog.offered(read: [model("claude-fable-5-1")])
        let second = ClaudeModelCatalog.offered(read: first, including: "fable", observed: ["opus": "claude-opus-5-5"])

        #expect(second.filter { $0.id == "fable" }.map(\.displayName) == ["Fable 5.1"])
        #expect(second.filter { $0.id == "opus" }.map(\.displayName) == ["Opus 5.5"])
    }

    @Test("what an alias resolved to is kept per account")
    func keepsObservationsPerAccount() async throws {
        let store = try makeTestStore("resolved")

        await ClaudeResolvedModel.record(requested: "opus", reported: "claude-opus-5-5", account: work, in: store)
        await ClaudeResolvedModel.record(requested: "opus", reported: "claude-opus-5", account: client, in: store)
        await ClaudeResolvedModel.record(requested: "sonnet", reported: "claude-sonnet-5", account: nil, in: store)

        #expect(await ClaudeResolvedModel.observed(account: work, in: store) == ["opus": "claude-opus-5-5"])
        #expect(await ClaudeResolvedModel.observed(account: client, in: store) == ["opus": "claude-opus-5"])
        #expect(await ClaudeResolvedModel.observed(account: nil, in: store) == ["sonnet": "claude-sonnet-5"])
    }

    @Test("a later observation replaces the earlier one")
    func aNewVersionReplacesTheOldOne() async throws {
        let store = try makeTestStore("resolved")

        await ClaudeResolvedModel.record(requested: "opus", reported: "claude-opus-5", account: work, in: store)
        await ClaudeResolvedModel.record(requested: "opus", reported: "claude-opus-5-5", account: work, in: store)

        #expect(await ClaudeResolvedModel.observed(account: work, in: store) == ["opus": "claude-opus-5-5"])
    }

    @Test("only an alias answered with a real id of its family is recorded", arguments: [
        ("claude-opus-5-1", "claude-opus-5-1"),
        ("opus", "opus"),
        ("opus", "claude-sonnet-5"),
        ("opus", "definitely-not-a-model"),
    ])
    func recordsOnlyAResolvedAlias(requested: String, reported: String) async throws {
        let store = try makeTestStore("resolved")

        await ClaudeResolvedModel.record(requested: requested, reported: reported, account: work, in: store)

        #expect(await ClaudeResolvedModel.observed(account: work, in: store).isEmpty)
    }

    @Test("forgetting an account forgets what it resolved to, and no other account's")
    func forgettingAnAccountForgetsItsObservations() async throws {
        let store = try makeTestStore("resolved")
        try await store.add(AgentAccountRow(
            id: work.id, provider: .claudeCode, directory: work.directory.path, label: "Work",
            createdAt: Date(timeIntervalSince1970: 1_000)
        ))
        for alias in ClaudeModelCatalog.builtIn.map(\.id) {
            await ClaudeResolvedModel.record(requested: alias, reported: "claude-\(alias)-5", account: work, in: store)
        }
        await ClaudeResolvedModel.record(requested: "opus", reported: "claude-opus-5", account: client, in: store)

        try await store.forgetAgentAccount(work.id)

        #expect(await ClaudeResolvedModel.observed(account: work, in: store).isEmpty)
        #expect(await ClaudeResolvedModel.observed(account: client, in: store) == ["opus": "claude-opus-5"])
    }
}
