import Testing
import Foundation
@testable import Core

func claudeLine(
    _ output: Int,
    directory: String = "/Users/ada/work",
    identity: String? = nil,
    model: String = "claude-opus-5",
    input: Int = 1
) -> String {
    """
    {"type":"assistant","timestamp":"2026-10-11T12:00:00.000Z","cwd":"\(directory)",\
    "message":{"id":"\(identity ?? "msg_\(output)")","model":"\(model)",\
    "usage":{"input_tokens":\(input),"output_tokens":\(output),\
    "cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}
    """
}

func idlessLine(_ output: Int) -> String {
    """
    {"type":"assistant","timestamp":"2026-10-11T12:00:00.000Z","cwd":"/Users/ada/work",\
    "message":{"model":"claude-opus-5","usage":{"input_tokens":1,"output_tokens":\(output),\
    "cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}
    """
}

func codexContext(_ model: String, directory: String) -> String {
    """
    {"timestamp":"2026-10-11T11:00:00.000Z","ordinal":1,"type":"turn_context",\
    "payload":{"turn_id":"t","cwd":"\(directory)","model":"\(model)"}}
    """
}

func codexCount(_ output: Int) -> String {
    """
    {"timestamp":"2026-10-11T11:30:00.000Z","ordinal":2,"type":"event_msg",\
    "payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":10,\
    "cached_input_tokens":4,"cache_write_input_tokens":0,"output_tokens":\(output)}}}}
    """
}

struct SpendHome {
    let root: URL

    init() throws {
        root = URL(filePath: TestScratch.unique("spend-home"), directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: root.appending(path: ".claude/projects/-Users-ada-work"), withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: root.appending(path: ".codex/sessions/2026/10/11"), withIntermediateDirectories: true
        )
    }

    var claude: URL { root.appending(path: ".claude/projects/-Users-ada-work/session.jsonl") }

    var codex: URL {
        root.appending(
            path: ".codex/sessions/2026/10/11/rollout-2026-10-11T11-00-00-0199a-7a22-a753-be11-87e74249.jsonl"
        )
    }

    func write(_ text: String, to url: URL) throws {
        try Data(text.utf8).write(to: url)
    }
}

func spendCensus(in store: Store) async throws -> SpendCensus? {
    guard let stored = try await store.setting(SpendCensus.settingKey) else { return nil }
    return try JSONDecoder().decode(SpendCensus.self, from: Data(stored.utf8))
}

func spendTotals(in store: Store) async throws -> TokenUsage {
    let days = try await store.spendDays(since: Date(timeIntervalSince1970: 0))
    return TokenUsage.sum(days.map(\.usage))
}
