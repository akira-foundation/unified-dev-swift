import Testing
import Foundation
@testable import Core

private let secret = "SPRUCE-GOOSE-9173"

private func strings(in value: Any) -> [String] {
    if let text = value as? String { return [text] }
    let mirror = Mirror(reflecting: value)
    if mirror.children.isEmpty { return [] }
    return mirror.children.flatMap { strings(in: $0.value) }
}

private func claudeLineHoldingASecret() -> String {
    """
    {"type":"assistant","timestamp":"2026-10-09T12:00:00.000Z","cwd":"/Users/ada/work",\
    "sessionId":"abc","message":{"role":"assistant","content":[{"type":"text","text":"\(secret)"},\
    {"type":"tool_use","name":"Bash","input":{"command":"echo \(secret)"}}],\
    "model":"claude-opus-5","usage":{"input_tokens":1,"output_tokens":2,\
    "cache_read_input_tokens":3,"cache_creation_input_tokens":4}}}
    """
}

@Suite("Usage reading privacy")
struct UsageReadingPrivacyTests {
    @Test("a scanned turn carries no word of the message")
    func recordHoldsNoContent() throws {
        var carry = TranscriptCarry()
        let record = try #require(
            UsageLine.record(inLine: claudeLineHoldingASecret(), provider: .claudeCode, carry: &carry)
        )
        for text in strings(in: record) {
            #expect(!text.contains(secret))
        }
    }

    @Test("every string a scanned turn carries is a field we asked for")
    func recordHoldsOnlyUsageFields() throws {
        var carry = TranscriptCarry()
        let record = try #require(
            UsageLine.record(inLine: claudeLineHoldingASecret(), provider: .claudeCode, carry: &carry)
        )
        let wanted: Set<String> = ["claude-opus-5", "/Users/ada/work", AgentKind.claudeCode.rawValue]
        #expect(Set(strings(in: record)).subtracting(wanted).isEmpty)
    }

    @Test("a transcript read off disk carries no word of its messages")
    func fileReadingHoldsNoContent() throws {
        let directory = URL(filePath: NSTemporaryDirectory())
            .appending(path: "spend-privacy-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appending(path: "session.jsonl")
        let lines = (0..<20).map { _ in claudeLineHoldingASecret() }.joined(separator: "\n") + "\n"
        try Data(lines.utf8).write(to: url)

        let file = TranscriptFile(provider: .claudeCode, url: url, size: lines.utf8.count, modifiedAt: Date())
        let result = try TranscriptReader.read(file, from: 0, carry: TranscriptCarry())

        #expect(result.records.count == 20)
        for text in result.records.flatMap({ strings(in: $0) }) {
            #expect(!text.contains(secret))
        }
        for text in strings(in: result.carry) {
            #expect(!text.contains(secret))
        }
    }

    @Test("a field longer than the limit is dropped instead of carried")
    func longFieldIsDropped() throws {
        let fat = String(repeating: "x", count: JSONCursor.textLimit + 1)
        let line = """
        {"type":"assistant","timestamp":"2026-10-09T12:00:00.000Z","cwd":"\(fat)",\
        "message":{"model":"claude-opus-5","usage":{"input_tokens":1,"output_tokens":2}}}
        """
        var carry = TranscriptCarry()
        let record = try #require(UsageLine.record(inLine: line, provider: .claudeCode, carry: &carry))
        #expect(record.directory.isEmpty)
    }
}
