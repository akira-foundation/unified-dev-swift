import Testing
import Foundation
@testable import Core

private func claudeLine(
    _ output: Int,
    directory: String = "/Users/ada/work",
    identity: String? = nil
) -> String {
    """
    {"type":"assistant","timestamp":"2026-10-11T12:00:00.000Z","cwd":"\(directory)",\
    "message":{"id":"\(identity ?? "msg_\(output)")","model":"claude-opus-5",\
    "usage":{"input_tokens":1,"output_tokens":\(output),\
    "cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}
    """
}

private func codexContext(_ model: String, directory: String) -> String {
    """
    {"timestamp":"2026-10-11T11:00:00.000Z","ordinal":1,"type":"turn_context",\
    "payload":{"turn_id":"t","cwd":"\(directory)","model":"\(model)"}}
    """
}

private func codexCount(_ output: Int) -> String {
    """
    {"timestamp":"2026-10-11T11:30:00.000Z","ordinal":2,"type":"event_msg",\
    "payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":10,\
    "cached_input_tokens":4,"cache_write_input_tokens":0,"output_tokens":\(output)}}}}
    """
}

private struct Home {
    let root: URL

    init() throws {
        root = URL(filePath: TestScratch.unique("spend-home"))
        try FileManager.default.createDirectory(
            at: root.appending(path: ".claude/projects/-Users-ada-work"), withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: root.appending(path: ".codex/sessions/2026/10/11"), withIntermediateDirectories: true
        )
    }

    var claude: URL { root.appending(path: ".claude/projects/-Users-ada-work/session.jsonl") }
    var codex: URL { root.appending(path: ".codex/sessions/2026/10/11/rollout-2026-10-11T11-00-00-0199a-7a22-a753-be11-87e74249.jsonl") }

    func write(_ text: String, to url: URL) throws {
        try Data(text.utf8).write(to: url)
    }

    func size(of url: URL) throws -> Int {
        try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
    }

    func modified(of url: URL) throws -> Date {
        try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date()
    }
}

private func census(_ store: Store) async throws -> SpendCensus? {
    guard let stored = try await store.setting(SpendCensus.settingKey) else { return nil }
    return try JSONDecoder().decode(SpendCensus.self, from: Data(stored.utf8))
}

private func totals(_ store: Store) async throws -> TokenUsage {
    let days = try await store.spendDays(since: Date(timeIntervalSince1970: 0))
    return TokenUsage.sum(days.map(\.usage))
}

@Suite("Spend census", .tags(.persistence))
struct SpendCensusTests {
    @Test("a cancelled build does not report the transcripts it never read as measured")
    func cancellationLeavesThemPending() async throws {
        let home = try Home()
        try home.write([claudeLine(10), claudeLine(20)].joined(separator: "\n") + "\n", to: home.claude)
        try home.write(codexCount(1) + "\n", to: home.codex)

        let store = try makeTestStore("indexer")
        let indexer = SpendIndexer(store: store, home: home.root, environment: [:])
        let task = Task { () async throws -> SpendIndexOutcome in
            while !Task.isCancelled { await Task.yield() }
            return try await indexer.refresh()
        }
        task.cancel()
        _ = try await task.value

        let census = try #require(try await census(store))
        #expect(census[.claudeCode]?.pending == 1)
        let board = SpendBoard.make(SpendBoard.Input(
            days: [], census: census, installed: [.claudeCode], window: .week
        ))
        #expect(board.providers.first?.reading == .stillReading(pending: 1))
    }

    @Test("a provider that keeps no usage on disk is recorded as keeping none")
    func providerThatKeepsNoUsage() async throws {
        let home = try Home()
        try home.write(claudeLine(10) + "\n", to: home.claude)

        let store = try makeTestStore("indexer")
        _ = try await SpendIndexer(store: store, home: home.root, environment: [:]).refresh()

        let census = try #require(try await census(store))
        #expect(census[.grok]?.keepsTranscripts == false)
        let board = SpendBoard.make(SpendBoard.Input(
            days: [], census: census, installed: [.grok], window: .week
        ))
        #expect(board.providers.first?.reading == .keepsNoUsage)
    }

    @Test("a provider with no transcript directory is recorded as keeping none")
    func providerWithoutTranscripts() async throws {
        let home = try Home()
        try home.write(claudeLine(10) + "\n", to: home.claude)

        let store = try makeTestStore("indexer")
        let indexer = SpendIndexer(store: store, home: home.root, environment: [:])
        _ = try await indexer.refresh()

        let census = try #require(try await census(store))
        #expect(census[.claudeCode]?.keepsTranscripts == true)
        #expect(census[.codex]?.keepsTranscripts == false)
        #expect(census[.codex]?.files == 0)
    }
}
