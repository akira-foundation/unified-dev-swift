import Foundation
import Testing
@testable import Core

@Suite("workspace_say braking a loop", .tags(.persistence), .scratchDirectory)
struct WorkspaceSayThrottleToolTests {
    private func fill(_ f: WorkspaceSayFixture, count: Int, now: Date = Date()) async throws {
        let spacing = WorkspaceSayThrottle.window / Double(WorkspaceSayThrottle.limit + 1)
        for index in 0..<count {
            _ = try await f.store.enqueueWorkspaceMessage(
                WorkspaceMessage(
                    source: WorkspaceMessageEnd(
                        workspaceID: f.fixer.id, workspace: f.fixer.name,
                        sessionID: f.fixerChat.id, chat: f.fixerChat.title
                    ),
                    target: WorkspaceMessageEnd(workspaceID: f.releaser.id, workspace: f.releaser.name),
                    text: "Update \(index)",
                    createdAt: now.addingTimeInterval(-Double(index) * spacing)
                ),
                into: f.releaserChat
            )
        }
    }

    @Test("the store counts one direction inside the window, cancelled left out, newest first")
    func storeCountsTheWindow() async throws {
        let f = try await WorkspaceSayFixture.make("throttle-store")
        let now = Date()
        try await fill(f, count: 3, now: now)
        let window = WorkspaceSayWindow(store: f.store, chats: f.chats)
        _ = await workspaceSay("Cancel me.", to: f.releaser, as: f.fixerIdentity, with: window.tool(), store: f.store)
        _ = try await f.store.cancelWorkspaceMessage(id: try #require(window.sent.last?.id))

        let recent = try await f.store.workspaceMessages(
            from: f.fixer.id, to: f.releaser.id, since: now.addingTimeInterval(-WorkspaceSayThrottle.window)
        )
        let reverse = try await f.store.workspaceMessages(
            from: f.releaser.id, to: f.fixer.id, since: now.addingTimeInterval(-WorkspaceSayThrottle.window)
        )

        #expect(recent.map(\.text) == ["Update 0", "Update 1", "Update 2"])
        #expect(reverse.isEmpty)
    }

    @Test("the thirty-first message inside ten minutes is refused, and nothing is queued for it")
    func refusesPastTheLimit() async throws {
        let f = try await WorkspaceSayFixture.make("throttle-limit")
        try await fill(f, count: WorkspaceSayThrottle.limit)
        let window = WorkspaceSayWindow(store: f.store, chats: f.chats)

        let result = await workspaceSay("One more.", to: f.releaser, as: f.fixerIdentity, with: window.tool(), store: f.store)

        #expect(result.isError)
        #expect(result.text.contains("\(WorkspaceSayThrottle.limit) messages"))
        #expect(window.sent.isEmpty)
    }

    @Test("one short of the limit still goes")
    func underTheLimit() async throws {
        let f = try await WorkspaceSayFixture.make("throttle-under")
        try await fill(f, count: WorkspaceSayThrottle.limit - 1)
        let window = WorkspaceSayWindow(store: f.store, chats: f.chats)

        let result = await workspaceSay("One more.", to: f.releaser, as: f.fixerIdentity, with: window.tool(), store: f.store)

        #expect(!result.isError, "\(result.text)")
    }

    @Test("the same words twice inside the window are refused the second time")
    func repeatedWords() async throws {
        let f = try await WorkspaceSayFixture.make("throttle-repeat")
        let window = WorkspaceSayWindow(store: f.store, chats: f.chats)
        let tool = window.tool()

        let first = await workspaceSay("Thanks, got it.", to: f.releaser, as: f.fixerIdentity, with: tool, store: f.store)
        let second = await workspaceSay("Thanks, got it.", to: f.releaser, as: f.fixerIdentity, with: tool, store: f.store)

        #expect(!first.isError)
        #expect(second.isError)
        #expect(second.text.contains("already sent exactly that message"))
        #expect(window.sent.count == 1)
    }

    @Test("the other direction is braked separately")
    func perDirection() async throws {
        let f = try await WorkspaceSayFixture.make("throttle-direction")
        try await fill(f, count: WorkspaceSayThrottle.limit)
        let window = WorkspaceSayWindow(store: f.store, chats: f.chats)

        let answer = await workspaceSay("Done.", to: f.fixer, as: f.releaserIdentity, with: window.tool(), store: f.store)

        #expect(!answer.isError, "\(answer.text)")
    }

    @Test("the owner's own client is not braked")
    func ownerIsExempt() async throws {
        let f = try await WorkspaceSayFixture.make("throttle-owner")
        let window = WorkspaceSayWindow(store: f.store, chats: f.chats)
        let tool = window.tool()

        let first = await workspaceSay("Status?", to: f.releaser, as: .owner, with: tool, store: f.store)
        let second = await workspaceSay("Status?", to: f.releaser, as: .owner, with: tool, store: f.store)

        #expect(!first.isError)
        #expect(!second.isError, "\(second.text)")
    }

    @Test("the description tells the model about both rules before it sends anything")
    func described() {
        let description = WorkspaceSayTool { _ in .refused("") }.tool.description
        #expect(description.contains("\(WorkspaceSayThrottle.limit) messages"))
        #expect(description.contains("Do not thank or acknowledge"))
    }
}
