import Foundation
import Testing
@testable import Core

@Suite("Ask Unified Dev on the bridge")
struct BridgeAskIdentityTests {
    @Test("an Ask chat is the owner, and says which chat it is")
    func askIsTheOwnerWithAChat() {
        let registry = BridgeRegistry()
        registry.admit(ownerToken: "owner")
        let chat = SessionID(rawValue: "s-ask")

        let token = registry.mintOwner(sessionID: chat)
        let identity = registry.identity(forToken: token)

        #expect(token != "owner")
        #expect(identity == BridgeIdentity(ownerSession: chat))
        #expect(identity?.role == .owner)
        #expect(identity?.workspaceID == nil)
        #expect(identity?.sessionID == chat)
        #expect(registry.liveSessions == [chat])
        #expect(registry.identity(forToken: "owner") == .owner)
    }

    @Test("regenerating the owner's token cuts the Ask chats off too")
    func regeneratingRevokesAsk() {
        let registry = BridgeRegistry()
        registry.admit(ownerToken: "old")
        let token = registry.mintOwner(sessionID: SessionID(rawValue: "s-ask"))

        registry.admit(ownerToken: "new")

        #expect(registry.identity(forToken: token) == nil)
        #expect(registry.identity(forToken: "old") == nil)
        #expect(registry.identity(forToken: "new") == .owner)
    }

    @Test("reading the same owner's token again leaves the Ask chats connected")
    func readmittingKeepsAsk() {
        let registry = BridgeRegistry()
        registry.admit(ownerToken: "same")
        let chat = SessionID(rawValue: "s-ask")
        let token = registry.mintOwner(sessionID: chat)

        registry.admit(ownerToken: "same")

        #expect(registry.identity(forToken: token) == BridgeIdentity(ownerSession: chat))
    }

    @Test("closing the Ask chat retires its token")
    func retiring() {
        let registry = BridgeRegistry()
        let chat = SessionID(rawValue: "s-ask")
        let token = registry.mintOwner(sessionID: chat)

        registry.retire(sessionID: chat)

        #expect(registry.identity(forToken: token) == nil)
        #expect(registry.liveSessions.isEmpty)
    }

    @Test("a tool answers an Ask chat exactly as it answers the owner", .tags(.persistence), .scratchDirectory)
    func toolsSeeTheOwner() async throws {
        let store = try makeTestStore("ask-whoami")
        let ask = try await store.upsert(Session(workspaceID: nil, title: "Ask"))
        let request = MCPRequest(id: .number(1), method: "whoami", params: .object([:]))

        let asOwner = await WhoamiTool().call(request, as: .owner, store: store)
        let asAsk = await WhoamiTool().call(request, as: BridgeIdentity(ownerSession: ask.id), store: store)

        #expect(asAsk == asOwner)
    }
}
