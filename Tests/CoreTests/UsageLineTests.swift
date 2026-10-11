import Testing
import Foundation
@testable import Core

private func claudeLine(
    model: String = "claude-opus-5",
    content: String = "hello",
    input: Int = 12,
    output: Int = 34,
    read: Int = 56,
    short: Int = 0,
    long: Int = 78
) -> String {
    """
    {"type":"assistant","timestamp":"2026-10-09T12:00:00.000Z",\
    "cwd":"/Users/ada/work","sessionId":"abc","isSidechain":false,\
    "message":{"role":"assistant","content":[{"type":"text","text":"\(content)"}],\
    "model":"\(model)","usage":{"input_tokens":\(input),"output_tokens":\(output),\
    "cache_read_input_tokens":\(read),"cache_creation_input_tokens":\(short + long),\
    "cache_creation":{"ephemeral_5m_input_tokens":\(short),"ephemeral_1h_input_tokens":\(long)},\
    "service_tier":"standard"}}}
    """
}

private func codexContext(model: String, directory: String) -> String {
    """
    {"timestamp":"2026-10-09T11:59:00.000Z","ordinal":3,"type":"turn_context",\
    "payload":{"turn_id":"t1","cwd":"\(directory)","model":"\(model)","effort":"high"}}
    """
}

private func codexCount(input: Int, cached: Int, write: Int, output: Int) -> String {
    """
    {"timestamp":"2026-10-09T12:00:00.000Z","ordinal":4,"type":"event_msg",\
    "payload":{"type":"token_count","info":{"total_token_usage":\
    {"input_tokens":999999,"cached_input_tokens":999999,"output_tokens":999999},\
    "last_token_usage":{"input_tokens":\(input),"cached_input_tokens":\(cached),\
    "cache_write_input_tokens":\(write),"output_tokens":\(output),"reasoning_output_tokens":9},\
    "model_context_window":258400},"rate_limits":{"limit_id":"codex"}}}
    """
}

@Suite("Usage lines")
struct UsageLineTests {
    @Test("a Claude turn gives its five columns apart")
    func claudeColumns() throws {
        var carry = TranscriptCarry()
        let record = try #require(
            UsageLine.record(inLine: claudeLine(), provider: .claudeCode, carry: &carry)
        )
        #expect(record.usage == TokenUsage(
            freshInput: 12, cacheRead: 56, cacheWriteShort: 0, cacheWriteLong: 78, output: 34
        ))
        #expect(record.model == "claude-opus-5")
        #expect(record.directory == "/Users/ada/work")
        #expect(record.provider == .claudeCode)
    }

    @Test("a cache write with no breakdown counts as the five minute window")
    func claudeWithoutBreakdown() throws {
        let line = """
        {"type":"assistant","timestamp":"2026-10-09T12:00:00.000Z","cwd":"/w",\
        "message":{"model":"claude-opus-5","usage":{"input_tokens":1,"output_tokens":2,\
        "cache_read_input_tokens":3,"cache_creation_input_tokens":40}}}
        """
        var carry = TranscriptCarry()
        let record = try #require(UsageLine.record(inLine: line, provider: .claudeCode, carry: &carry))
        #expect(record.usage.cacheWriteShort == 40)
        #expect(record.usage.cacheWriteLong == 0)
    }

    @Test("a usage object written inside a message is not counted")
    func usageInsideContentIsIgnored() throws {
        let quoted = #"{\"usage\":{\"input_tokens\":500000,\"output_tokens\":900000}}"#
        var carry = TranscriptCarry()
        let record = try #require(
            UsageLine.record(inLine: claudeLine(content: quoted), provider: .claudeCode, carry: &carry)
        )
        #expect(record.usage.freshInput == 12)
        #expect(record.usage.output == 34)
    }

    @Test("a line with no usage gives no record")
    func withoutUsage() {
        var carry = TranscriptCarry()
        let line = #"{"type":"user","timestamp":"2026-10-09T12:00:00.000Z","cwd":"/w","message":{"role":"user","content":"hi"}}"#
        #expect(UsageLine.record(inLine: line, provider: .claudeCode, carry: &carry) == nil)
    }

    @Test("a line cut in half gives no record")
    func truncatedLine() {
        var carry = TranscriptCarry()
        let whole = claudeLine()
        let half = String(whole.prefix(whole.count / 2))
        #expect(UsageLine.record(inLine: half, provider: .claudeCode, carry: &carry) == nil)
    }

    @Test("Codex counts only what the turn used, not the session total")
    func codexTurnDelta() throws {
        var carry = TranscriptCarry()
        _ = UsageLine.record(
            inLine: codexContext(model: "gpt-6-sol", directory: "/Users/ada/api"),
            provider: .codex,
            carry: &carry
        )
        let record = try #require(UsageLine.record(
            inLine: codexCount(input: 34_450, cached: 17_664, write: 0, output: 163),
            provider: .codex,
            carry: &carry
        ))
        #expect(record.usage.cacheRead == 17_664)
        #expect(record.usage.freshInput == 34_450 - 17_664)
        #expect(record.usage.output == 163)
        #expect(record.model == "gpt-6-sol")
        #expect(record.directory == "/Users/ada/api")
    }

    @Test("a Codex count before any turn context carries no model")
    func codexWithoutContext() throws {
        var carry = TranscriptCarry()
        let record = try #require(UsageLine.record(
            inLine: codexCount(input: 10, cached: 0, write: 0, output: 5),
            provider: .codex,
            carry: &carry
        ))
        #expect(record.model.isEmpty)
        #expect(ModelPrices.spend(of: record.usage, model: record.model, provider: .codex).hasUnpricedTokens)
    }

    @Test("a provider that keeps no usage on disk reads no record")
    func providerWithoutTranscripts() {
        var carry = TranscriptCarry()
        #expect(UsageLine.record(inLine: claudeLine(), provider: .grok, carry: &carry) == nil)
    }
}
