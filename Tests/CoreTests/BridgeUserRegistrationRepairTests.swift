import Foundation
import Testing
@testable import Core

@Suite("BridgeUserRegistrationRepair")
struct BridgeUserRegistrationRepairTests {
    private let moved = "/Applications/UnifiedDev.app/Contents/MacOS/bridge"
    private let gone = "/Users/freek/Applications/UnifiedDev.app/Contents/MacOS/bridge"

    private var attachment: BridgeAttachment {
        BridgeAttachment(
            shimPath: moved,
            socketPath: "/tmp/bridge-abc123.sock",
            token: "0123456789abcdef",
            role: .owner
        )
    }

    private func entry(
        command: String,
        socket: String? = nil,
        token: String? = nil,
        role: String = "owner"
    ) -> [String: Any] {
        [
            "type": "stdio",
            "command": command,
            "args": [String](),
            "env": [
                BridgeProtocol.socketVariable: socket ?? attachment.socketPath,
                BridgeProtocol.tokenVariable: token ?? attachment.token,
                BridgeProtocol.roleVariable: role,
            ],
        ]
    }

    private func config(_ servers: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "numStartups": 412,
            "oauthAccount": ["emailAddress": "you@example.com"],
            "projects": ["/Users/freek/dev/code/unifieddev": ["allowedTools": [String]()]],
            "mcpServers": servers,
        ])
    }

    private func decide(
        _ data: Data?,
        serverNamed name: String = "unifieddev",
        present: Set<String> = []
    ) -> BridgeUserRegistrationRepair.Repair {
        BridgeUserRegistrationRepair.decide(
            userConfig: data,
            serverNamed: name,
            matching: attachment,
            shimExists: { present.contains($0) }
        )
    }

    private func command(in data: Data, serverNamed name: String) throws -> String? {
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let servers = root?["mcpServers"] as? [String: Any]
        return (servers?[name] as? [String: Any])?["command"] as? String
    }

    @Test("An entry already on this bundle's shim is left alone")
    func correctEntry() throws {
        let data = try config(["unifieddev": entry(command: moved)])
        #expect(decide(data, present: [moved]) == .leaveAlone(.alreadyCorrect))
    }

    @Test("Our entry pointing at a bundle that has gone is re-pointed at this one")
    func repairsTheMove() throws {
        let data = try config(["unifieddev": entry(command: gone)])
        guard case .rewrite(let rewritten, let from, let to) = decide(data, present: [moved]) else {
            Issue.record("a stale entry of ours should be repaired")
            return
        }
        #expect(from == gone)
        #expect(to == moved)
        let repointed = try command(in: rewritten, serverNamed: "unifieddev")
        #expect(repointed == moved)
    }

    @Test("The repair changes one string and carries the rest of the file through")
    func keepsEverythingElse() throws {
        let data = try config([
            "unifieddev": entry(command: gone),
            "figma": ["command": "/opt/homebrew/bin/figma-mcp"],
        ])
        guard case .rewrite(let rewritten, _, _) = decide(data, present: [moved]) else {
            Issue.record("a stale entry of ours should be repaired")
            return
        }
        let root = try #require(try JSONSerialization.jsonObject(with: rewritten) as? [String: Any])
        #expect(root["numStartups"] as? Int == 412)
        #expect((root["oauthAccount"] as? [String: Any])?["emailAddress"] as? String == "you@example.com")
        #expect((root["projects"] as? [String: Any])?.count == 1)
        let neighbour = try command(in: rewritten, serverNamed: "figma")
        #expect(neighbour == "/opt/homebrew/bin/figma-mcp")
        let servers = try #require(root["mcpServers"] as? [String: Any])
        let ours = try #require(servers["unifieddev"] as? [String: Any])
        #expect(ours["type"] as? String == "stdio")
        #expect((ours["env"] as? [String: Any])?[BridgeProtocol.tokenVariable] as? String == attachment.token)
    }

    @Test("An entry naming another app is not ours to move, whatever it is called")
    func somebodyElsesEntry() throws {
        let strangeSocket = try config(["unifieddev": entry(command: gone, socket: "/tmp/bridge-other.sock")])
        let strangeToken = try config(["unifieddev": entry(command: gone, token: "deadbeef")])
        let noEnvironment = try config(["unifieddev": ["command": gone]])
        let wrapper = try config(["unifieddev": entry(command: "/Users/freek/bin/bridge-wrapper")])
        #expect(decide(strangeSocket) == .leaveAlone(.notOurs))
        #expect(decide(strangeToken) == .leaveAlone(.notOurs))
        #expect(decide(noEnvironment) == .leaveAlone(.notOurs))
        #expect(decide(wrapper) == .leaveAlone(.notOurs))
    }

    @Test("An entry pointing at a shim that is still there is a working arrangement, not a move")
    func deliberateCrossWire() throws {
        let elsewhere = "/Users/freek/Applications/Unified Dev (Dev).app/Contents/MacOS/bridge"
        let data = try config(["unifieddev": entry(command: elsewhere)])
        #expect(decide(data, present: [moved, elsewhere]) == .leaveAlone(.shimStillThere))
    }

    @Test("The release copy does not touch the dev copy's entry, and the dev copy cannot take ours")
    func theThreeIdentities() throws {
        let devShim = "/Users/freek/Applications/Unified Dev (Dev).app/Contents/MacOS/bridge"
        let dev: [String: Any] = [
            "command": devShim,
            "env": [
                BridgeProtocol.socketVariable: "/tmp/bridge-def456.sock",
                BridgeProtocol.tokenVariable: "fedcba9876543210",
                BridgeProtocol.roleVariable: "owner",
            ],
        ]
        let data = try config(["unifieddev": entry(command: gone), "unifieddev-dev": dev])
        guard case .rewrite(let rewritten, _, _) = decide(data, present: []) else {
            Issue.record("the release copy's own entry should still be repaired")
            return
        }
        let ours = try command(in: rewritten, serverNamed: "unifieddev")
        let theirs = try command(in: rewritten, serverNamed: "unifieddev-dev")
        #expect(ours == moved)
        #expect(theirs == devShim)

        let devAttachment = BridgeAttachment(
            shimPath: devShim,
            socketPath: "/tmp/bridge-def456.sock",
            token: "fedcba9876543210",
            role: .owner
        )
        let refused = BridgeUserRegistrationRepair.decide(
            userConfig: data,
            serverNamed: "unifieddev",
            matching: devAttachment,
            shimExists: { _ in false }
        )
        #expect(refused == .leaveAlone(.notOurs))
    }

    @Test("A missing file, an empty one, and no table at all are all left alone")
    func nothingToRepair() throws {
        let emptyTable = try config([:])
        let somebodyElse = try config(["figma": entry(command: gone)])
        #expect(decide(nil) == .leaveAlone(.unreadable))
        #expect(decide(Data()) == .leaveAlone(.unreadable))
        #expect(decide(Data("{}".utf8)) == .leaveAlone(.absent))
        #expect(decide(emptyTable) == .leaveAlone(.absent))
        #expect(decide(somebodyElse) == .leaveAlone(.absent))
    }

    @Test("JSON this app did not expect is somebody else's file, and is not rewritten")
    func malformed() {
        #expect(decide(Data(#"{"mcpServers": {"unifieddev":"#.utf8)) == .leaveAlone(.malformed))
        #expect(decide(Data("not json at all".utf8)) == .leaveAlone(.malformed))
        #expect(decide(Data("[1, 2, 3]".utf8)) == .leaveAlone(.malformed))
        #expect(decide(Data(#"{"mcpServers": "none"}"#.utf8)) == .leaveAlone(.absent))
        #expect(decide(Data(#"{"mcpServers": {"unifieddev": "none"}}"#.utf8)) == .leaveAlone(.absent))
    }

    @Test("The written file is atomic, keeps its mode, and is only touched on a real difference")
    func writesThroughToDisk() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("unifieddev-repair-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("claude.json").path

        try config(["unifieddev": entry(command: gone)]).write(to: URL(fileURLWithPath: path))
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)

        let repaired = BridgeUserRegistrationRepair.repairIfStale(
            path: path,
            serverNamed: "unifieddev",
            matching: attachment,
            shimExists: { _ in false }
        )
        #expect(repaired == .repaired(from: gone, to: moved))
        let written = try #require(FileManager.default.contents(atPath: path))
        let repointed = try command(in: written, serverNamed: "unifieddev")
        #expect(repointed == moved)
        let mode = try FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? NSNumber
        #expect(mode?.intValue == 0o600)

        let again = BridgeUserRegistrationRepair.repairIfStale(
            path: path,
            serverNamed: "unifieddev",
            matching: attachment,
            shimExists: { _ in false }
        )
        #expect(again == .unchanged(.alreadyCorrect))
        #expect(FileManager.default.contents(atPath: path) == written)
    }

    @Test("A file that is not there is not created")
    func absentFileIsNotWritten() {
        let path = NSTemporaryDirectory() + "/unifieddev-repair-\(UUID().uuidString)/claude.json"
        let outcome = BridgeUserRegistrationRepair.repairIfStale(
            path: path,
            serverNamed: "unifieddev",
            matching: attachment,
            shimExists: { _ in false }
        )
        #expect(outcome == .unchanged(.unreadable))
        #expect(!FileManager.default.fileExists(atPath: path))
    }
    @Test("A preview repairs only its own entry, never the real copy's or another preview's")
    func previewLeavesOtherCopiesAlone() throws {
        let preview = BridgeRegistration.ownerServerName(
            forBundleIdentifier: PreviewIdentity.bundlePrefix + "worktree-preview-apps"
        )
        let real = BridgeRegistration.ownerServerName(forBundleIdentifier: Store.primaryBundleIdentifier)
        let otherPreview = BridgeRegistration.ownerServerName(
            forBundleIdentifier: PreviewIdentity.bundlePrefix + "sending-slot"
        )
        #expect(Set([preview, real, otherPreview]).count == 3)

        let data = try config([
            real: entry(command: gone, socket: "/tmp/bridge-real.sock", token: "real-token"),
            otherPreview: entry(command: gone, socket: "/tmp/bridge-other.sock", token: "other-token"),
        ])
        #expect(decide(data, serverNamed: preview, present: [moved]) == .leaveAlone(.absent))
        #expect(decide(data, serverNamed: real, present: [moved]) == .leaveAlone(.notOurs))
        #expect(decide(data, serverNamed: otherPreview, present: [moved]) == .leaveAlone(.notOurs))
    }
}
