import Testing
import Foundation
@testable import Core

private let now = Date(timeIntervalSince1970: 1_791_676_800)

private func turn(
    key: String,
    file: String = "/t/a.jsonl",
    day: Date = now,
    model: String = "claude-opus-5",
    directory: String = "/Users/ada/work",
    tier: PriceTier = .base,
    usage: TokenUsage = TokenUsage(freshInput: 1, cacheRead: 2, cacheWriteShort: 3, cacheWriteLong: 4, output: 5)
) -> SpendTurn {
    SpendTurn(
        file: file,
        key: key,
        provider: .claudeCode,
        day: day,
        model: model,
        directory: directory,
        tier: tier,
        usage: usage
    )
}

private func cursor(_ file: String = "/t/a.jsonl", offset: Int = 10) -> TranscriptCursor {
    TranscriptCursor(
        path: file, provider: .claudeCode, size: max(100, offset), modifiedAt: now, offset: offset
    )
}

@Suite("Spend store", .tags(.persistence))
struct SpendStoreTests {
    @Test("a turn written twice is counted once")
    func sameTurnTwice() async throws {
        let store = try makeTestStore("spend")
        try await store.record([turn(key: "msg_1")], reaching: cursor())
        try await store.record([turn(key: "msg_1")], reaching: cursor(offset: 20))
        let days = try await store.spendDays(since: now.addingTimeInterval(-86_400))
        #expect(days.count == 1)
        #expect(days.first?.turns == 1)
        #expect(days.first?.usage.output == 5)
    }

    @Test("two turns of the same day add up")
    func twoTurnsAddUp() async throws {
        let store = try makeTestStore("spend")
        try await store.record([turn(key: "msg_1"), turn(key: "msg_2")], reaching: cursor())
        let days = try await store.spendDays(since: now.addingTimeInterval(-86_400))
        #expect(days.count == 1)
        #expect(days.first?.turns == 2)
        #expect(days.first?.usage == TokenUsage(
            freshInput: 2, cacheRead: 4, cacheWriteShort: 6, cacheWriteLong: 8, output: 10
        ))
    }

    @Test("one response copied into a second transcript is still one turn")
    func oneResponseAcrossTwoTranscripts() async throws {
        let store = try makeTestStore("spend")
        try await store.record([turn(key: "msg_1")], reaching: cursor())
        try await store.record([turn(key: "msg_1", file: "/t/b.jsonl")], reaching: cursor("/t/b.jsonl"))
        let days = try await store.spendDays(since: now.addingTimeInterval(-86_400))
        #expect(days.count == 1)
        #expect(days.first?.file == "/t/a.jsonl")
    }

    @Test("two turns of another provider with the same key stay apart")
    func providersHaveTheirOwnKeys() async throws {
        let store = try makeTestStore("spend")
        var codex = turn(key: "1")
        codex.provider = .codex
        try await store.record([turn(key: "1"), codex], reaching: cursor())
        let days = try await store.spendDays(since: now.addingTimeInterval(-86_400))
        #expect(Set(days.map(\.provider)) == [.claudeCode, .codex])
    }

    @Test("two models, two directories and two price tiers on one day stay apart")
    func groupingKeepsThemApart() async throws {
        let store = try makeTestStore("spend")
        try await store.record(
            [
                turn(key: "a", model: "claude-opus-5"),
                turn(key: "b", model: "claude-opus-5-5"),
                turn(key: "c", directory: "/Users/ada/other"),
                turn(key: "d", tier: .longPrompt),
            ],
            reaching: cursor()
        )
        let days = try await store.spendDays(since: now.addingTimeInterval(-86_400))
        #expect(days.count == 4)
        #expect(Set(days.map(\.model)) == ["claude-opus-5", "claude-opus-5-5"])
        #expect(Set(days.map(\.tier)) == [.base, .longPrompt])
    }

    @Test("a day before the window is not read back")
    func windowFilters() async throws {
        let store = try makeTestStore("spend")
        try await store.record(
            [turn(key: "a"), turn(key: "b", day: now.addingTimeInterval(-40 * 86_400))],
            reaching: cursor()
        )
        let days = try await store.spendDays(since: now.addingTimeInterval(-7 * 86_400))
        #expect(days.count == 1)
    }

    @Test("forgetting a transcript drops every turn it wrote and no others")
    func forgetting() async throws {
        let store = try makeTestStore("spend")
        try await store.record([turn(key: "a"), turn(key: "b")], reaching: cursor())
        try await store.record([turn(key: "c", file: "/t/b.jsonl")], reaching: cursor("/t/b.jsonl"))
        try await store.forgetSpend(ofFile: "/t/a.jsonl")
        let days = try await store.spendDays(since: now.addingTimeInterval(-86_400))
        #expect(days.map(\.file) == ["/t/b.jsonl"])
    }

    @Test("a cursor and its turns land in one write")
    func cursorRoundTrip() async throws {
        let store = try makeTestStore("spend")
        let reached = TranscriptCursor(
            path: "/t/a.jsonl",
            provider: .codex,
            size: 900,
            modifiedAt: now,
            offset: 512,
            carry: TranscriptCarry(model: "gpt-6-sol", directory: "/Users/ada/work")
        )
        try await store.record([turn(key: "a")], reaching: reached)
        #expect(try await store.transcriptCursors()["/t/a.jsonl"] == reached)
    }

    @Test("a cursor written again moves rather than multiplying")
    func cursorMoves() async throws {
        let store = try makeTestStore("spend")
        try await store.record([], reaching: cursor(offset: 100))
        try await store.record([], reaching: cursor(offset: 900))
        let read = try await store.transcriptCursors()
        #expect(read.count == 1)
        #expect(read["/t/a.jsonl"]?.offset == 900)
    }
}
