import Testing
import Foundation
@testable import Core

private let now = Date(timeIntervalSince1970: 1_791_676_800)

private func row(
    day: Date,
    file: String = "/t/a.jsonl",
    model: String = "claude-opus-5",
    directory: String = "/Users/ada/work",
    usage: TokenUsage = TokenUsage(freshInput: 1, cacheRead: 2, cacheWriteShort: 3, cacheWriteLong: 4, output: 5),
    turns: Int = 1
) -> SpendDay {
    SpendDay(
        provider: .claudeCode,
        day: day,
        model: model,
        directory: directory,
        agentSessionID: "abc",
        file: file,
        usage: usage,
        turns: turns
    )
}

@Suite("Spend store", .tags(.persistence))
struct SpendStoreTests {
    @Test("a day written twice adds up instead of replacing itself")
    func writesAddUp() async throws {
        let store = try makeTestStore("spend")
        try await store.add([row(day: now)])
        try await store.add([row(day: now)])
        let days = try await store.spendDays(since: now.addingTimeInterval(-86_400))
        #expect(days.count == 1)
        #expect(days.first?.usage == TokenUsage(
            freshInput: 2, cacheRead: 4, cacheWriteShort: 6, cacheWriteLong: 8, output: 10
        ))
        #expect(days.first?.turns == 2)
    }

    @Test("two models on the same day are kept apart")
    func modelsStayApart() async throws {
        let store = try makeTestStore("spend")
        try await store.add([row(day: now, model: "claude-opus-5"), row(day: now, model: "claude-opus-5-5")])
        let days = try await store.spendDays(since: now.addingTimeInterval(-86_400))
        #expect(Set(days.map(\.model)) == ["claude-opus-5", "claude-opus-5-5"])
    }

    @Test("a day before the window is not read back")
    func windowFilters() async throws {
        let store = try makeTestStore("spend")
        try await store.add([
            row(day: now),
            row(day: now.addingTimeInterval(-40 * 86_400), file: "/t/old.jsonl"),
        ])
        let days = try await store.spendDays(since: now.addingTimeInterval(-7 * 86_400))
        #expect(days.count == 1)
    }

    @Test("forgetting a transcript drops every day it wrote")
    func forgetting() async throws {
        let store = try makeTestStore("spend")
        try await store.add([
            row(day: now, file: "/t/a.jsonl"),
            row(day: now.addingTimeInterval(-86_400), file: "/t/a.jsonl"),
            row(day: now, file: "/t/b.jsonl"),
        ])
        try await store.forgetSpend(ofFile: "/t/a.jsonl")
        let days = try await store.spendDays(since: now.addingTimeInterval(-7 * 86_400))
        #expect(days.map(\.file) == ["/t/b.jsonl"])
    }

    @Test("a cursor comes back with the place and the model it stopped at")
    func cursorRoundTrip() async throws {
        let store = try makeTestStore("spend")
        let cursor = TranscriptCursor(
            path: "/t/a.jsonl",
            provider: .codex,
            size: 900,
            modifiedAt: now,
            offset: 512,
            carry: TranscriptCarry(model: "gpt-6-sol", directory: "/Users/ada/work")
        )
        try await store.remember(cursor)
        let read = try await store.transcriptCursors()
        #expect(read["/t/a.jsonl"] == cursor)
    }

    @Test("a cursor written again moves rather than multiplying")
    func cursorMoves() async throws {
        let store = try makeTestStore("spend")
        let first = TranscriptCursor(
            path: "/t/a.jsonl", provider: .claudeCode, size: 900, modifiedAt: now, offset: 100
        )
        try await store.remember(first)
        var moved = first
        moved.offset = 900
        try await store.remember(moved)
        let read = try await store.transcriptCursors()
        #expect(read.count == 1)
        #expect(read["/t/a.jsonl"]?.offset == 900)
    }
}
