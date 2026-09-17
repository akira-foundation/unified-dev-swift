import Testing
import Foundation
@testable import Core

@Suite("Quick prompt store", .tags(.persistence), .scratchDirectory)
struct QuickPromptStoreTests {
    @Test("round-trips a prompt")
    func roundTrips() async throws {
        let store = try makeTestStore("quick-prompts")
        let written = try await store.insert(
            QuickPrompt(name: "Tests", symbol: "hammer", text: "Run make test.")
        )

        let loaded = try await store.quickPrompts()
        #expect(loaded.count == 1)
        #expect(loaded[0].id == written.id)
        #expect(loaded[0].name == "Tests")
        #expect(loaded[0].symbol == "hammer")
        #expect(loaded[0].text == "Run make test.")
    }

    @Test("keeps prompts in the order they were written")
    func keepsOrder() async throws {
        let store = try makeTestStore("quick-prompts")
        for name in ["first", "second", "third"] {
            try await store.insert(QuickPrompt(name: name, text: name))
        }

        #expect(try await store.quickPrompts().map(\.name) == ["first", "second", "third"])
        #expect(try await store.quickPrompts().map(\.sortOrder) == [0, 1, 2])
    }

    @Test("an update writes only what it changed")
    func updatesNarrowly() async throws {
        let store = try makeTestStore("quick-prompts")
        let written = try await store.insert(
            QuickPrompt(name: "Tests", symbol: "hammer", text: "Run make test.")
        )

        let changed = try await store.update(quickPromptID: written.id) { $0.name = "Run tests" }
        #expect(changed?.name == "Run tests")

        let loaded = try await store.quickPrompts()
        #expect(loaded.count == 1)
        #expect(loaded[0].name == "Run tests")
        #expect(loaded[0].symbol == "hammer")
        #expect(!loaded[0].sendsImmediately)
        #expect(!loaded[0].opensNewChat)
        #expect(loaded[0].text == "Run make test.")
        #expect(loaded[0].sortOrder == written.sortOrder)
        #expect(abs(loaded[0].createdAt.timeIntervalSince(written.createdAt)) < 0.001)
    }

    @Test("an update to a prompt that is gone changes nothing and says so")
    func updatesNothing() async throws {
        let store = try makeTestStore("quick-prompts")
        let missing = try await store.update(quickPromptID: QuickPromptID.new()) { $0.name = "x" }
        #expect(missing == nil)
        #expect(try await store.quickPrompts().isEmpty)
    }

    @Test("deletes one prompt and leaves the rest")
    func deletes() async throws {
        let store = try makeTestStore("quick-prompts")
        let first = try await store.insert(QuickPrompt(name: "first", text: "a"))
        try await store.insert(QuickPrompt(name: "second", text: "b"))

        try await store.deleteQuickPrompt(id: first.id)
        #expect(try await store.quickPrompts().map(\.name) == ["second"])
    }

    @Test("the two switches round-trip, on the insert and on the update")
    func roundTripsDelivery() async throws {
        let store = try makeTestStore("quick-prompts")
        let written = try await store.insert(
            QuickPrompt(name: "Ship it", text: "Push the branch.")
        )
        #expect(!written.sendsImmediately)
        #expect(!written.opensNewChat)
        #expect(try await store.quickPrompts().first?.sendsImmediately == false)

        let changed = try await store.update(quickPromptID: written.id) {
            $0.sendsImmediately = true
            $0.opensNewChat = true
        }
        #expect(changed?.sendsImmediately == true)

        let loaded = try #require(try await store.quickPrompt(id: written.id))
        #expect(loaded.sendsImmediately)
        #expect(loaded.opensNewChat)
        #expect(loaded.text == "Push the branch.")

        _ = try await store.update(quickPromptID: written.id) { $0.sendsImmediately = false }
        let after = try #require(try await store.quickPrompt(id: written.id))
        #expect(!after.sendsImmediately)
        #expect(after.opensNewChat)
    }

    @Test("a prompt written before the columns existed reads with both switches off")
    func migration() async throws {
        let path = TestScratch.unique("quick-prompt-delivery-migration") + ".sqlite"
        let store = try Store(path: path)
        let old = try await store.insert(QuickPrompt(name: "Explain", text: "Explain the changes."))
        let opted = try await store.insert(QuickPrompt(name: "Ship it", text: "Push."))
        _ = try await store.update(quickPromptID: opted.id) { $0.sendsImmediately = true }

        let raw = try SQLiteDatabase(path: path)
        try raw.setUserVersion(0)

        let reopened = try Store(path: path)
        let plain = try #require(try await reopened.quickPrompt(id: old.id))
        #expect(!plain.sendsImmediately)
        #expect(!plain.opensNewChat)
        #expect(try await reopened.quickPrompt(id: opted.id)?.sendsImmediately == true)

        let fresh = try await reopened.insert(QuickPrompt(name: "New", text: "Anything."))
        #expect(!fresh.sendsImmediately)
        #expect(!fresh.opensNewChat)
    }

    @Test("a fresh database is seeded with the built-ins")
    func seeds() async throws {
        let store = try makeTestStore("quick-prompts")
        let seeded = try await store.seedQuickPrompts()

        #expect(seeded.count == QuickPromptSeed.all.count)
        #expect(seeded.map(\.name) == QuickPromptSeed.all.map(\.name))
        #expect(seeded.allSatisfy { !$0.sendsImmediately && !$0.opensNewChat })
        #expect(try await store.setting(QuickPromptSeed.versionKey) == String(QuickPromptSeed.version))
    }

    @Test("seeding twice inserts nothing the second time")
    func seedsOnce() async throws {
        let store = try makeTestStore("quick-prompts")
        try await store.seedQuickPrompts()
        try await store.seedQuickPrompts()
        try await store.seedQuickPrompts()

        #expect(try await store.quickPrompts().count == QuickPromptSeed.all.count)
    }

    @Test("a deleted built-in stays deleted across relaunches")
    func deletedBuiltInStaysDeleted() async throws {
        let path = TestScratch.unique("quick-prompt-seed") + ".sqlite"
        let first = try Store(path: path)
        let seeded = try await first.seedQuickPrompts()
        let built = try #require(seeded.first)
        try await first.deleteQuickPrompt(id: built.id)
        #expect(try await first.quickPrompts().isEmpty)

        let relaunched = try Store(path: path)
        let after = try await relaunched.seedQuickPrompts()
        #expect(after.isEmpty)
    }

    @Test("a built-in deleted through the bridge stays deleted, and no tool can reseed it")
    func deletedThroughTheBridgeStaysDeleted() async throws {
        let path = TestScratch.unique("quick-prompt-bridge-seed") + ".sqlite"
        let first = try Store(path: path)

        let listed = await tool(QuickPromptListTool(), on: first)
        #expect(!listed.isError)
        let built = try #require(try await first.quickPrompts().first)
        #expect(built.name == QuickPromptSeed.all.first?.name)

        let deleted = await tool(
            QuickPromptDeleteTool(), ["id": .string(built.id.rawValue)], on: first
        )
        #expect(!deleted.isError)
        #expect(try await first.quickPrompts().isEmpty)

        _ = await tool(QuickPromptListTool(), on: first)
        #expect(try await first.quickPrompts().isEmpty)

        let relaunched = try Store(path: path)
        #expect(try await relaunched.seedQuickPrompts().isEmpty)
        #expect(
            try await relaunched.setting(QuickPromptSeed.versionKey)
                == String(QuickPromptSeed.version)
        )
    }

    private func tool(
        _ handler: any BridgeToolHandling,
        _ arguments: [String: JSONValue] = [:],
        on store: Store
    ) async -> BridgeToolResult {
        await handler.call(
            MCPRequest(id: .number(1), method: handler.tool.name, params: .object(arguments)),
            as: .owner,
            store: store
        )
    }

    @Test("a later built-in inserts itself and resurrects nothing")
    func laterBuiltIn() async throws {
        let store = try makeTestStore("quick-prompts")
        try await store.seedQuickPrompts()
        for prompt in try await store.quickPrompts() {
            try await store.deleteQuickPrompt(id: prompt.id)
        }

        let next = QuickPromptSeed.Entry(
            name: "Later", symbol: "sparkles", text: "Something new.",
            introducedIn: QuickPromptSeed.version + 1
        )
        #expect(QuickPromptSeed.pending(installed: QuickPromptSeed.version).isEmpty)

        try await store.insert(next.prompt(sortOrder: 0))
        #expect(try await store.quickPrompts().map(\.name) == ["Later"])
    }
}
