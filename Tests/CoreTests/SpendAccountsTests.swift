import Testing
import Foundation
@testable import Core

@Suite("Spend accounts")
struct SpendAccountsTests {
    private let someone = URL(filePath: "/Users/someone")

    private var defaultClaude: AgentAccountHome {
        AgentAccountHome.defaultHome(for: .claudeCode, home: someone)!
    }

    private static func claudeHome(id: String, at path: String) -> AgentAccountHome {
        AgentAccountHome(
            provider: .claudeCode,
            id: AgentAccountID(id),
            directory: URL(filePath: path, directoryHint: .isDirectory),
            isDefault: false
        )
    }

    private let workClaude = claudeHome(id: "work", at: "/Users/someone/.claude-work")

    @Test func aTranscriptIsAttributedToTheAccountDirectoryItSitsUnder() {
        let home = SpendAccounts.account(
            ofFile: "/Users/someone/.claude/projects/-a-b/x.jsonl", among: [defaultClaude, workClaude]
        )
        #expect(home?.id == defaultClaude.id)
    }

    @Test func theLongestMatchingDirectoryWinsWhenOneAccountSitsInsideAnother() {
        let outer = Self.claudeHome(id: "outer", at: "/Users/someone/.config")
        let inner = Self.claudeHome(id: "inner", at: "/Users/someone/.config/claude")
        let home = SpendAccounts.account(
            ofFile: "/Users/someone/.config/claude/projects/-a/x.jsonl", among: [outer, inner]
        )
        #expect(home?.id == inner.id)
    }

    @Test func aTranscriptOutsideEveryKnownAccountIsNotAttributed() {
        #expect(SpendAccounts.account(ofFile: "/elsewhere/x.jsonl", among: [defaultClaude]) == nil)
    }

    @Test func aSiblingDirectorySharingAPrefixIsNotTheAccountDirectory() {
        let home = SpendAccounts.account(
            ofFile: "/Users/someone/.claude-work/projects/x.jsonl", among: [defaultClaude]
        )
        #expect(home == nil)
    }

    @Test func aPathWithDotSegmentsIsSettledBeforeItIsCompared() {
        let home = SpendAccounts.account(
            ofFile: "/Users/someone/.claude/projects/../projects/-a/x.jsonl", among: [defaultClaude]
        )
        #expect(home?.id == defaultClaude.id)
    }

    @Test func aTranscriptReachedThroughASymlinkedAccountDirectoryStillMatches() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "spend-accounts-\(UUID().uuidString)", directoryHint: .isDirectory)
        let real = root.appending(path: "dotfiles", directoryHint: .isDirectory)
        let link = root.appending(path: "link", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: real.appending(path: "projects", directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
        defer { try? FileManager.default.removeItem(at: root) }

        let account = Self.claudeHome(id: "linked", at: link.path)
        let home = SpendAccounts.account(
            ofFile: real.appending(path: "projects/x.jsonl").path, among: [account]
        )
        #expect(home?.id == account.id)
    }

    @Test func theDefaultHomesAreTheConventionalDirectoriesWhenNothingOverridesThem() {
        let homes = SpendAccounts.defaultHomes(home: someone, environment: [:])
        #expect(homes.count == 2)
        #expect(homes.map(\.directory.path) == ["/Users/someone/.claude", "/Users/someone/.codex"])
        #expect(homes.map(\.id.rawValue) == ["default.claudeCode", "default.codex"])
        let allDefault = homes.allSatisfy { $0.isDefault }
        #expect(allDefault)
    }

    @Test func anOverriddenConfigDirectoryIsNotTheConventionalOne() {
        let homes = SpendAccounts.defaultHomes(
            home: someone, environment: ["CLAUDE_CONFIG_DIR": "/elsewhere/claude"]
        )
        let claude = homes.first { $0.provider == .claudeCode }
        #expect(claude?.directory.path == "/elsewhere/claude")
        #expect(claude?.isDefault == false)
        #expect(claude?.identityPath.path == "/elsewhere/claude/.claude.json")
        #expect(homes.first { $0.provider == .codex }?.isDefault == true)
    }

    @Test func theDefaultHomesAreTheDirectoriesTheIndexerReads() {
        let environment = ["CLAUDE_CONFIG_DIR": "/elsewhere/claude"]
        let homes = SpendAccounts.defaultHomes(home: someone, environment: environment)
        let sources = TranscriptSources.sources(home: someone, environment: environment)
        #expect(homes.map(\.directory) == sources.map(\.home))
    }
}
