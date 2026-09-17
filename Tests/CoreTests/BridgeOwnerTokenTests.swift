import Foundation
import Testing
@testable import Core

@Suite("The owner's bridge token", .scratchDirectory)
struct BridgeOwnerTokenTests {
    private func token(_ label: String = "owner") -> BridgeOwnerToken {
        BridgeOwnerToken(path: TestScratch.unique(label) + "/bridge-owner-token")
    }

    @Test("the first read mints one and writes it where the second read finds it")
    func persists() throws {
        let store = token()

        let first = try store.load()
        let second = try store.load()

        #expect(!first.isEmpty)
        #expect(first == second)
        #expect(FileManager.default.fileExists(atPath: store.path))
    }

    @Test("a fresh instance on the same path reads back the same token")
    func survivesARelaunch() throws {
        let path = TestScratch.unique("relaunch") + "/bridge-owner-token"

        let before = try BridgeOwnerToken(path: path).load()
        let after = try BridgeOwnerToken(path: path).load()

        #expect(before == after)
    }

    @Test("the file and the directory holding it are not readable by anybody else")
    func modes() throws {
        let store = token("modes")
        _ = try store.load()

        let manager = FileManager.default
        let file = try manager.attributesOfItem(atPath: store.path)[.posixPermissions] as? NSNumber
        let directory = (store.path as NSString).deletingLastPathComponent
        let folder = try manager.attributesOfItem(atPath: directory)[.posixPermissions] as? NSNumber

        #expect(file?.int16Value == 0o600)
        #expect(folder?.int16Value == 0o700)
    }

    @Test("regenerating replaces it, which is the whole of revoking it")
    func regenerates() throws {
        let store = token("regen")
        let first = try store.load()

        let second = try store.regenerate()

        #expect(first != second)
        #expect(try store.load() == second)
    }

    @Test("whitespace around a hand edited token is ignored")
    func trimmed() throws {
        let store = token("trimmed")
        let written = try store.load()
        try Data("\n  \(written)  \n".utf8).write(to: URL(fileURLWithPath: store.path))

        #expect(try store.load() == written)
    }

    @Test("an empty file is treated as no file at all")
    func emptyFileRemints() throws {
        let store = token("empty")
        _ = try store.load()
        try Data("\n".utf8).write(to: URL(fileURLWithPath: store.path))

        #expect(!(try store.load().isEmpty))
    }

    @Test("it lives beside the database, so two copies of Unified Dev cannot share one")
    func besideTheDatabase() {
        let one = BridgeOwnerToken.beside(databasePath: "/x/Unified Dev/unifieddev.sqlite")
        let other = BridgeOwnerToken.beside(databasePath: "/x/Unified Dev (Dev)/unifieddev.sqlite")

        #expect(one.path == "/x/Unified Dev/bridge-owner-token")
        #expect(one.path != other.path)
    }
}

@Suite("Admitting the owner")
struct BridgeOwnerAdmissionTests {
    @Test("an admitted token resolves to the owner, in no session and no workspace")
    func admits() {
        let registry = BridgeRegistry()

        registry.admit(ownerToken: "abc")

        let identity = registry.identity(forToken: "abc")
        #expect(identity?.role == .owner)
        #expect(identity?.workspaceID == nil)
        #expect(identity?.sessionID == nil)
    }

    @Test("admitting a new one retires the last, so regenerating really does revoke")
    func replaces() {
        let registry = BridgeRegistry()
        registry.admit(ownerToken: "old")

        registry.admit(ownerToken: "new")

        #expect(registry.identity(forToken: "old") == nil)
        #expect(registry.identity(forToken: "new")?.role == .owner)
    }

    @Test("the owner's token is not a live session")
    func notASession() {
        let registry = BridgeRegistry()
        registry.admit(ownerToken: "abc")

        #expect(registry.liveSessions.isEmpty)
    }

    @Test("a session token still says which workspace, and is not the owner")
    func sessionsAreUnaffected() {
        let registry = BridgeRegistry()
        let token = registry.mint(
            sessionID: SessionID(rawValue: "s1"),
            workspaceID: WorkspaceID(rawValue: "w1"),
            role: .parent
        )
        registry.admit(ownerToken: "abc")

        #expect(registry.identity(forToken: token)?.role == .parent)
        #expect(registry.identity(forToken: token)?.workspaceID == WorkspaceID(rawValue: "w1"))
    }
}

@Suite("What the owner copies out of Settings")
struct BridgeOwnerCommandTests {
    private func attachment(
        shim: String = "/Applications/UnifiedDev.app/Contents/MacOS/bridge",
        socket: String = "/tmp/bridge-abc.sock",
        token: String = "deadbeef"
    ) -> BridgeAttachment {
        BridgeAttachment(shimPath: shim, socketPath: socket, token: token, role: .owner)
    }

    @Test("it is one command, at user scope, naming the shim and the three variables")
    func shape() {
        let command = BridgeRegistration.ownerAddCommand(attachment())

        #expect(command.hasPrefix("claude mcp add --scope user "))
        #expect(command.contains(BridgeRegistration.ownerServerName))
        #expect(command.contains("-e 'UD_BRIDGE_SOCKET=/tmp/bridge-abc.sock'"))
        #expect(command.contains("-e 'UD_BRIDGE_TOKEN=deadbeef'"))
        #expect(command.contains("-e 'UD_BRIDGE_ROLE=owner'"))
        #expect(command.hasSuffix("-- '/Applications/UnifiedDev.app/Contents/MacOS/bridge'"))
    }

    @Test("Codex receives the same owner connection")
    func codexShape() {
        let command = BridgeRegistration.ownerCodexAddCommand(attachment())

        #expect(command.hasPrefix("codex mcp add \(BridgeRegistration.ownerServerName) "))
        #expect(command.contains("--env 'UD_BRIDGE_SOCKET=/tmp/bridge-abc.sock'"))
        #expect(command.contains("--env 'UD_BRIDGE_TOKEN=deadbeef'"))
        #expect(command.contains("--env 'UD_BRIDGE_ROLE=owner'"))
        #expect(command.hasSuffix("-- '/Applications/UnifiedDev.app/Contents/MacOS/bridge'"))
    }

    @Test("Grok receives the same owner connection")
    func grokShape() {
        let command = BridgeRegistration.ownerGrokAddCommand(attachment())

        #expect(command.hasPrefix("grok mcp add --scope user \(BridgeRegistration.ownerServerName) "))
        #expect(command.contains("-e 'UD_BRIDGE_SOCKET=/tmp/bridge-abc.sock'"))
        #expect(command.contains("-e 'UD_BRIDGE_TOKEN=deadbeef'"))
        #expect(command.contains("-e 'UD_BRIDGE_ROLE=owner'"))
        #expect(command.hasSuffix("-- '/Applications/UnifiedDev.app/Contents/MacOS/bridge'"))
    }

    @Test("the standalone server is not named the same as the per session one")
    func distinctName() {
        #expect(BridgeRegistration.ownerServerName != BridgeRegistration.serverName)
    }

    @Test("each copy of Unified Dev registers under a name of its own")
    func namePerInstance() {
        #expect(
            BridgeRegistration.ownerServerName(forBundleIdentifier: Store.primaryBundleIdentifier)
                == "unified-dev"
        )
        #expect(
            BridgeRegistration.ownerServerName(forBundleIdentifier: Store.devBundleIdentifier)
                == "unified-dev-dev"
        )
        #expect(
            BridgeRegistration.ownerServerName(forBundleIdentifier: "io.akira.unifieddev.beta")
                == "unified-dev-io-akira-unifieddev-beta"
        )
        #expect(BridgeRegistration.ownerServerName(forBundleIdentifier: nil) == "unified-dev-unbundled")
    }

    @Test("a name is lower case, hyphenated, and never empty")
    func slugs() {
        #expect(BridgeRegistration.slugified("Unified Dev (Dev)") == "unified-dev-dev")
        #expect(BridgeRegistration.slugified("  Unified Dev (caf\u{e9} 2) ") == "unified-dev-caf-2")
        #expect(BridgeRegistration.slugified("...") == "")
        #expect(BridgeRegistration.ownerServerName(forBundleIdentifier: nil).isEmpty == false)
    }

    @Test("a path with a space in it survives the shell")
    func quotesPaths() {
        let command = BridgeRegistration.ownerAddCommand(
            attachment(shim: "/Users/me/Applications/Unified Dev (Dev).app/Contents/MacOS/bridge")
        )

        #expect(command.hasSuffix(
            "-- '/Users/me/Applications/Unified Dev (Dev).app/Contents/MacOS/bridge'"
        ))
    }

    @Test("a quote in a value cannot close the string early")
    func quotesQuotes() {
        #expect(BridgeRegistration.shellQuoted("it's") == #"'it'\''s'"#)
    }
}
