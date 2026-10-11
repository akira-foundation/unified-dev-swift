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

@Suite("Spend indexer", .tags(.persistence))
struct SpendIndexerTests {
    @Test("the first build reads both providers and keeps what it found")
    func firstBuild() async throws {
        let home = try Home()
        try home.write([claudeLine(10), claudeLine(20)].joined(separator: "\n") + "\n", to: home.claude)
        try home.write([codexContext("gpt-6-sol", directory: "/Users/ada/api"), codexCount(7)]
            .joined(separator: "\n") + "\n", to: home.codex)

        let store = try makeTestStore("indexer")
        let indexer = SpendIndexer(store: store, home: home.root, environment: [:])
        let outcome = try await indexer.refresh()

        #expect(outcome.finished)
        #expect(outcome.filesRead == 2)
        #expect(outcome.turns == 3)
        let days = try await store.spendDays(since: Date(timeIntervalSince1970: 0))
        #expect(Set(days.map(\.provider)) == [.claudeCode, .codex])
        #expect(TokenUsage.sum(days.map(\.usage)).output == 37)
        #expect(days.first { $0.provider == .codex }?.model == "gpt-6-sol")
        #expect(days.first { $0.provider == .codex }?.directory == "/Users/ada/api")
    }

    @Test("a second refresh over unchanged transcripts reads nothing at all")
    func refreshReadsNothing() async throws {
        let home = try Home()
        try home.write(claudeLine(10) + "\n", to: home.claude)
        try home.write(codexCount(1) + "\n", to: home.codex)

        let store = try makeTestStore("indexer")
        let indexer = SpendIndexer(store: store, home: home.root, environment: [:])
        _ = try await indexer.refresh()
        let second = try await indexer.refresh()

        #expect(second.filesRead == 0)
        #expect(second.bytesRead == 0)
        #expect(try await totals(store).output == 11)
    }

    @Test("a transcript that grew while the app was open adds only its new turns")
    func growthIsAddedOnce() async throws {
        let home = try Home()
        try home.write(claudeLine(10) + "\n", to: home.claude)
        try home.write(codexCount(1) + "\n", to: home.codex)

        let store = try makeTestStore("indexer")
        let indexer = SpendIndexer(store: store, home: home.root, environment: [:])
        _ = try await indexer.refresh()

        try home.write([claudeLine(10), claudeLine(30)].joined(separator: "\n") + "\n", to: home.claude)
        let second = try await indexer.refresh()

        #expect(second.turns == 1)
        #expect(try await totals(store).output == 41)
    }

    @Test("a build stopped halfway carries on from where it stopped")
    func resumesFromTheCursor() async throws {
        let home = try Home()
        let first = claudeLine(10)
        try home.write([first, claudeLine(30)].joined(separator: "\n") + "\n", to: home.claude)
        try home.write(codexCount(1) + "\n", to: home.codex)

        let store = try makeTestStore("indexer")
        let listed = try #require(TranscriptSources.files(in: TranscriptSources.sources(
            home: home.root, environment: [:]
        )[0]).first)
        try await store.remember(TranscriptCursor(
            path: listed.url.path,
            provider: .claudeCode,
            size: 1,
            modifiedAt: Date(timeIntervalSince1970: 0),
            offset: first.utf8.count + 1
        ))

        let indexer = SpendIndexer(store: store, home: home.root, environment: [:])
        _ = try await indexer.refresh()
        #expect(try await totals(store).output == 31)
    }

    @Test("a transcript rewritten shorter is counted once, not twice")
    func rotationIsNotCountedTwice() async throws {
        let home = try Home()
        try home.write([claudeLine(10), claudeLine(20), claudeLine(30)].joined(separator: "\n") + "\n", to: home.claude)
        try home.write(codexCount(1) + "\n", to: home.codex)

        let store = try makeTestStore("indexer")
        let indexer = SpendIndexer(store: store, home: home.root, environment: [:])
        _ = try await indexer.refresh()
        #expect(try await totals(store).output == 61)

        try home.write(claudeLine(5) + "\n", to: home.claude)
        _ = try await indexer.refresh()
        #expect(try await totals(store).output == 6)
    }

    @Test("a cancelled build reports that it did not finish and writes nothing")
    func cancellationStops() async throws {
        let home = try Home()
        try home.write(claudeLine(10) + "\n", to: home.claude)
        try home.write(codexCount(1) + "\n", to: home.codex)

        let store = try makeTestStore("indexer")
        let indexer = SpendIndexer(store: store, home: home.root, environment: [:])
        let task = Task { () async throws -> SpendIndexOutcome in
            while !Task.isCancelled { await Task.yield() }
            return try await indexer.refresh()
        }
        task.cancel()
        let outcome = try await task.value

        #expect(!outcome.finished)
        #expect(outcome.filesRead == 0)
        #expect(try await totals(store).isEmpty)
    }

    @Test("one response written as several lines is counted once")
    func repeatedResponseCountedOnce() async throws {
        let home = try Home()
        try home.write(
            [
                claudeLine(10, identity: "msg_a"),
                claudeLine(10, identity: "msg_a"),
                claudeLine(10, identity: "msg_a"),
                claudeLine(30, identity: "msg_b"),
            ].joined(separator: "\n") + "\n",
            to: home.claude
        )

        let store = try makeTestStore("indexer")
        let indexer = SpendIndexer(store: store, home: home.root, environment: [:])
        _ = try await indexer.refresh()

        let days = try await store.spendDays(since: Date(timeIntervalSince1970: 0))
        #expect(days.count == 1)
        #expect(days.first?.turns == 2)
        #expect(try await totals(store).output == 40)
    }

    @Test("a provider every one of whose turns is unpriced is not read as nothing spent")
    func unpricedProviderIsNotZero() async throws {
        let home = try Home()
        try home.write(
            [codexContext("codex-auto-review", directory: "/Users/ada/api"), codexCount(9)]
                .joined(separator: "\n") + "\n",
            to: home.codex
        )

        let store = try makeTestStore("indexer")
        let indexer = SpendIndexer(store: store, home: home.root, environment: [:])
        _ = try await indexer.refresh()

        let days = try await store.spendDays(since: Date(timeIntervalSince1970: 0))
        let spend = Spend.sum(days.map(\.spend))
        #expect(spend.hasUnpricedTokens)
        #expect(SpendLines.cost(spend) == SpendLines.noPublishedPrice)
    }

    @Test("a transcript home named in the environment is the one read")
    func environmentHome() async throws {
        let home = try Home()
        let elsewhere = URL(filePath: TestScratch.unique("codex-home"))
        try FileManager.default.createDirectory(
            at: elsewhere.appending(path: "sessions"), withIntermediateDirectories: true
        )
        try home.write(
            [codexContext("gpt-6-sol", directory: "/Users/ada/api"), codexCount(9)].joined(separator: "\n") + "\n",
            to: elsewhere.appending(path: "sessions/rollout-2026-10-11T11-00-00-0199a-7a22-a753-be11-87e74249.jsonl")
        )

        let store = try makeTestStore("indexer")
        let indexer = SpendIndexer(
            store: store, home: home.root, environment: ["CODEX_HOME": elsewhere.path]
        )
        _ = try await indexer.refresh()
        #expect(try await totals(store).output == 9)
    }
}
