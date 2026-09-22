import Foundation
import Testing
@testable import Core

@Suite("Asking to be told when another workspace is done", .tags(.persistence), .scratchDirectory)
struct WorkspaceDoneWatchToolTests {
    private func say(
        _ f: WorkspaceSayFixture, as identity: BridgeIdentity, with tool: WorkspaceSayTool,
        notify: JSONValue? = nil
    ) async -> BridgeToolResult {
        var arguments: [String: JSONValue] = [
            "workspace": .string(f.releaser.id.rawValue), "message": .string("Release it."),
        ]
        if let notify { arguments["notify_when_done"] = notify }
        return await tool.call(
            MCPRequest(id: .number(1), method: "workspace_say", params: .object(arguments)),
            as: identity, store: f.store
        )
    }

    @Test("a message with the flag is written asking to be told, and the answer says so")
    func messageAsksToBeTold() async throws {
        let f = try await WorkspaceSayFixture.make("done-say")
        let window = WorkspaceSayWindow(store: f.store, chats: f.chats)

        let result = await say(f, as: f.fixerIdentity, with: window.tool(), notify: .bool(true))

        #expect(!result.isError, "\(result.text)")
        let answer = try #require(JSONValue.parse(result.text))
        #expect(answer["notify_when_done"] == .bool(true))
        #expect(answer["note"]?.stringValue?.contains("when the turn this message causes") == true)
        #expect(try #require(window.sent.first).notifyWhenDone)
        let watch = try #require(try await f.store.unspentWorkspaceDoneWatches(targetWorkspaceID: f.releaser.id).first)
        #expect(watch.watcherSessionID == f.fixerChat.id)
    }

    @Test("without the flag nothing is watched, and the answer says false")
    func withoutTheFlag() async throws {
        let f = try await WorkspaceSayFixture.make("done-say-without")
        let window = WorkspaceSayWindow(store: f.store, chats: f.chats)

        let result = await say(f, as: f.fixerIdentity, with: window.tool())

        let answer = try #require(JSONValue.parse(result.text))
        #expect(answer["notify_when_done"] == .bool(false))
        #expect(try await f.store.unspentWorkspaceDoneWatches(targetWorkspaceID: f.releaser.id).isEmpty)
    }

    @Test("the owner's own client has no chat to tell, and is told the flag was ignored")
    func ownerClientIsTold() async throws {
        let f = try await WorkspaceSayFixture.make("done-owner")
        let window = WorkspaceSayWindow(store: f.store, chats: f.chats)

        let result = await say(f, as: .owner, with: window.tool(), notify: .bool(true))

        #expect(!result.isError, "\(result.text)")
        #expect(result.text.contains("notify_when_done was ignored"))
        #expect(try await f.store.unspentWorkspaceDoneWatches(targetWorkspaceID: f.releaser.id).isEmpty)
    }

    @Test("the description tells the model what the one notice covers")
    func described() {
        let description = WorkspaceSayTool { _ in .refused("") }.tool.description
        #expect(description.contains("notify_when_done"))
        #expect(description.contains("comes to rest"))
    }
}
