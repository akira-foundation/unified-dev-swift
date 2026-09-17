import Foundation
import Testing
@testable import Core

@Suite("BridgeUserRegistration")
struct BridgeUserRegistrationTests {
    private let attachment = BridgeAttachment(
        shimPath: "/Applications/UnifiedDev.app/Contents/MacOS/bridge",
        socketPath: "/tmp/bridge-abc123.sock",
        token: "0123456789abcdef",
        role: .owner
    )

    private func config(_ servers: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["mcpServers": servers])
    }

    private func entry(
        command: String? = nil,
        socket: String? = nil,
        token: String? = nil,
        role: String = "owner"
    ) -> [String: Any] {
        [
            "type": "stdio",
            "command": command ?? attachment.shimPath,
            "args": [String](),
            "env": [
                BridgeProtocol.socketVariable: socket ?? attachment.socketPath,
                BridgeProtocol.tokenVariable: token ?? attachment.token,
                BridgeProtocol.roleVariable: role,
            ],
        ]
    }

    private func state(_ data: Data?) -> BridgeUserRegistration.State {
        BridgeUserRegistration.state(userConfig: data, serverNamed: "unifieddev", matching: attachment)
    }

    @Test("An entry naming this Unified Dev, this socket and this token is the offer already taken")
    func registered() throws {
        let data = try config(["unifieddev": entry()])
        #expect(state(data) == .registered)
    }

    @Test("The role is not compared, because an entry that disagrees about it still works")
    func ignoresTheRole() throws {
        let data = try config(["unifieddev": entry(role: "parent")])
        #expect(state(data) == .registered)
    }

    @Test("No table, an empty table, and somebody else's servers are all a straight no")
    func absent() throws {
        let empty = try config([:])
        let somebodyElse = try config(["figma": entry()])
        #expect(state(Data("{}".utf8)) == .notRegistered)
        #expect(state(empty) == .notRegistered)
        #expect(state(somebodyElse) == .notRegistered)
    }

    @Test("The name from before the rename does not count as this copy being registered")
    func theLegacyName() throws {
        let data = try config(["unifieddev-owner-bridge": entry()])
        #expect(state(data) == .notRegistered)
    }

    @Test("An entry wearing the name and pointing somewhere else is not registered")
    func stale() throws {
        let elsewhere = try config(["unifieddev": entry(command: "/Volumes/Old/bridge")])
        let otherSocket = try config(["unifieddev": entry(socket: "/tmp/bridge-other.sock")])
        let otherToken = try config(["unifieddev": entry(token: "deadbeef")])
        let noEnvironment = try config(["unifieddev": ["command": attachment.shimPath]])
        #expect(state(elsewhere) == .notRegistered)
        #expect(state(otherSocket) == .notRegistered)
        #expect(state(otherToken) == .notRegistered)
        #expect(state(noEnvironment) == .notRegistered)
    }

    @Test("A token that has been regenerated leaves the entry behind, and it counts as not done")
    func regenerated() throws {
        let old = BridgeAttachment(
            shimPath: attachment.shimPath,
            socketPath: attachment.socketPath,
            token: "the-revoked-one",
            role: .owner
        )
        let data = try config(["unifieddev": entry(token: old.token)])
        let state = BridgeUserRegistration.state(
            userConfig: data,
            serverNamed: "unifieddev",
            matching: attachment
        )
        #expect(state == .notRegistered)
    }

    @Test("A file that cannot be read or parsed is unknown, which is offered rather than assumed")
    func unknown() {
        #expect(state(nil) == .unknown)
        #expect(state(Data()) == .unknown)
        #expect(state(Data("not json at all".utf8)) == .unknown)
        #expect(state(Data("[1, 2, 3]".utf8)) == .unknown)
    }

    @Test("With no bridge to compare against, an entry of the right name is taken at face value")
    func noAttachment() throws {
        let data = try config(["unifieddev": entry()])
        let state = BridgeUserRegistration.state(
            userConfig: data,
            serverNamed: "unifieddev",
            matching: nil
        )
        #expect(state == .registered)
    }

    @Test("The name looked for is the one the command registers, per copy of Unified Dev")
    func namedPerCopy() throws {
        let dev = BridgeRegistration.ownerServerName(forBundleIdentifier: "io.akira.unifieddev.dev")
        #expect(dev == "unified-dev-dev")
        let data = try config(["unifieddev": entry()])
        let state = BridgeUserRegistration.state(userConfig: data, serverNamed: dev, matching: attachment)
        #expect(state == .notRegistered)
    }

    @Test("The path read is Claude Code's own configuration file")
    func path() {
        #expect(BridgeUserRegistration.userConfigPath == "\(NSHomeDirectory())/.claude.json")
    }
}
