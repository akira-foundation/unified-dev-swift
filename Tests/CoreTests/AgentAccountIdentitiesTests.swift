import Testing
import Foundation
@testable import Core

@Suite("Agent account identities")
struct AgentAccountIdentitiesTests {
    private let home = URL(filePath: "/Users/someone")

    private var defaultClaude: AgentAccountHome {
        AgentAccountHome.defaultHome(for: .claudeCode, home: home)!
    }

    private var defaultCodex: AgentAccountHome {
        AgentAccountHome.defaultHome(for: .codex, home: home)!
    }

    private let workClaude = AgentAccountHome(
        provider: .claudeCode,
        id: AgentAccountID("work"),
        directory: URL(filePath: "/support/AgentAccounts/claudeCode/work", directoryHint: .isDirectory),
        isDefault: false
    )

    @Test func eachAccountIsReadFromItsOwnDirectory() {
        let files: [String: String] = [
            "/Users/someone/.claude.json": #"{"oauthAccount":{"emailAddress":"personal@example.com"}}"#,
            "/support/AgentAccounts/claudeCode/work/.claude.json":
                #"{"oauthAccount":{"emailAddress":"work@example.com"}}"#,
        ]
        let identities = AgentAccountIdentities.read([defaultClaude, workClaude]) {
            files[$0.path].map { Data($0.utf8) }
        }
        #expect(identities[defaultClaude.id]?.email == "personal@example.com")
        #expect(identities[workClaude.id]?.email == "work@example.com")
    }

    @Test func anAccountWithNoFilesReadsAsNoSessionAndIsStillListed() {
        let identities = AgentAccountIdentities.read([defaultClaude, workClaude]) { _ in nil }
        #expect(identities.count == 2)
        #expect(identities[defaultClaude.id]?.authMethod == AgentAccountIdentity.Method.none)
        #expect(identities[workClaude.id]?.email == nil)
    }

    @Test func aFileServingTwoRolesIsOpenedOnlyOnce() {
        var reads: [URL] = []
        _ = AgentAccountIdentities.read([defaultCodex]) { path in
            reads.append(path)
            return nil
        }
        #expect(defaultCodex.identityPath == defaultCodex.credentialPath)
        #expect(reads == [defaultCodex.identityPath])
    }

    @Test func aClaudeAccountOpensItsIdentityAndItsCredentialApart() {
        var reads: [URL] = []
        _ = AgentAccountIdentities.read([defaultClaude]) { path in
            reads.append(path)
            return nil
        }
        #expect(reads == [defaultClaude.identityPath, defaultClaude.credentialPath])
    }

    @Test func theEmailAndThePlanAreReadFromRealFilesOnDisk() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "agent-accounts-\(UUID().uuidString)", directoryHint: .isDirectory)
        let directory = root.appending(path: "work", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let account = AgentAccountHome(
            provider: .claudeCode,
            id: AgentAccountID("work"),
            directory: directory,
            isDefault: false
        )
        try Data(#"{"oauthAccount":{"emailAddress":"on-disk@example.com"}}"#.utf8)
            .write(to: account.identityPath)
        try Data(#"{"claudeAiOauth":{"subscriptionType":"max"}}"#.utf8)
            .write(to: account.credentialPath)

        let identities = AgentAccountIdentities.read([account])
        #expect(identities[account.id]?.email == "on-disk@example.com")
        #expect(identities[account.id]?.plan == "Max")
    }
}
