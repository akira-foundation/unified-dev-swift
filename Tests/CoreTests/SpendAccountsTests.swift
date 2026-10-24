import Testing
import Foundation
@testable import Core

@Suite("Spend accounts")
struct SpendAccountsTests {
    private let defaultClaude = AgentAccountHome.defaultHome(
        for: .claudeCode, home: URL(filePath: "/Users/someone")
    )!
    private let defaultCodex = AgentAccountHome.defaultHome(
        for: .codex, home: URL(filePath: "/Users/someone")
    )!
    private let workClaude = claudeHome(id: "work", at: "/support/AgentAccounts/claudeCode/work")

    private static func claudeHome(id: String, at path: String) -> AgentAccountHome {
        AgentAccountHome(
            provider: .claudeCode,
            id: AgentAccountID(id),
            directory: URL(filePath: path, directoryHint: .isDirectory),
            isDefault: false
        )
    }

    @Test func aTranscriptIsAttributedToTheAccountDirectoryItSitsUnder() {
        let id = SpendAccounts.accountID(
            ofFile: "/Users/someone/.claude/projects/-a-b/x.jsonl", among: [defaultClaude, workClaude]
        )
        #expect(id == defaultClaude.id)
    }

    @Test func theLongestMatchingDirectoryWinsWhenOneAccountSitsInsideAnother() {
        let outer = Self.claudeHome(id: "outer", at: "/support/AgentAccounts/claudeCode")
        let inner = Self.claudeHome(id: "inner", at: "/support/AgentAccounts/claudeCode/inner")
        let id = SpendAccounts.accountID(
            ofFile: "/support/AgentAccounts/claudeCode/inner/projects/-a/x.jsonl",
            among: [outer, inner]
        )
        #expect(id == inner.id)
    }

    @Test func aTranscriptOutsideEveryKnownAccountIsNotAttributed() {
        #expect(SpendAccounts.accountID(ofFile: "/elsewhere/x.jsonl", among: [defaultClaude]) == nil)
    }

    @Test func aSiblingDirectorySharingAPrefixIsNotTheAccountDirectory() {
        let id = SpendAccounts.accountID(
            ofFile: "/Users/someone/.claude-work/projects/x.jsonl", among: [defaultClaude]
        )
        #expect(id == nil)
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
        let id = SpendAccounts.accountID(
            ofFile: real.appending(path: "projects/x.jsonl").path, among: [account]
        )
        #expect(id == account.id)
    }

    @Test func sourcesCarryOneRootPerAccountAndTagEachWithItsAccount() {
        let sources = TranscriptSources.sources(accounts: [defaultClaude, workClaude, defaultCodex])
        #expect(sources.count == 3)
        #expect(Set(sources.filter { $0.provider == .claudeCode }.map(\.accountID))
            == [defaultClaude.id, workClaude.id])
        #expect(sources.first { $0.accountID == defaultCodex.id }?.root.lastPathComponent == "sessions")
    }

    @Test func aProviderWithoutATranscriptLayoutContributesNoSource() {
        let grok = AgentAccountHome.defaultHome(for: .grok, home: URL(filePath: "/Users/someone"))!
        #expect(TranscriptSources.sources(accounts: [grok]).isEmpty)
    }

    @Test func theLegacySourcesCarryNoAccount() {
        let sources = TranscriptSources.sources(home: URL(filePath: "/Users/someone"), environment: [:])
        #expect(sources.allSatisfy { $0.accountID == nil })
    }
}
