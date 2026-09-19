import Foundation

public struct SubagentTranscript: Sendable, Equatable {
    public let messages: [Message]

    public let droppedRows: Int

    public let prompt: String

    public let printed: String

    public init(
        messages: [Message] = [],
        droppedRows: Int = 0,
        prompt: String = "",
        printed: String = ""
    ) {
        self.messages = messages
        self.droppedRows = droppedRows
        self.prompt = prompt
        self.printed = printed
    }

    public var isEmpty: Bool { messages.isEmpty && printed.isEmpty }

    public static let rowLimit = 500

    public static func parse(_ text: String, sessionID: SessionID) -> SubagentTranscript {
        var messages: [Message] = []
        var prompt = ""
        var used = Set<Int64>()

        for source in text.split(whereSeparator: \.isNewline) {
            let raw = Data(source.utf8)
            guard let json = JSONValue.parse(raw) else { continue }
            for reading in read(json, raw: raw) {
                switch reading {
                case .brief(let brief):
                    prompt = brief
                case .row(let kind, let payload, let refID):
                    messages.append(Message(
                        id: identifier(for: payload, avoiding: &used),
                        sessionID: sessionID,
                        seq: messages.count,
                        kind: kind,
                        payload: payload,
                        refID: refID
                    ))
                }
            }
        }

        let dropped = max(0, messages.count - rowLimit)
        return SubagentTranscript(
            messages: Array(messages.suffix(rowLimit)), droppedRows: dropped, prompt: prompt
        )
    }

    public static func live(streamLines: [Data], sessionID: SessionID) -> SubagentTranscript {
        parse(streamLines.map { String(decoding: $0, as: UTF8.self) }.joined(separator: "\n"), sessionID: sessionID)
    }

    public static func streamLines(_ calls: [(line: Data, result: Data?)]) -> [Data] {
        calls.flatMap { call in [call.line] + (call.result.map { [$0] } ?? []) }
    }

    public static func command(_ text: String) -> SubagentTranscript {
        SubagentTranscript(printed: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    public static func rowID(for payload: Data) -> Int64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in payload {
            hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01b3
        }
        return -Int64(hash & 0x7fff_ffff_ffff_ffff) - 1
    }

    private static func identifier(for payload: Data, avoiding used: inout Set<Int64>) -> Int64 {
        var id = rowID(for: payload)
        while used.contains(id) { id -= 1 }
        used.insert(id)
        return id
    }

    private enum Reading {
        case brief(String)
        case row(kind: MessageKind, payload: Data, refID: String?)
    }

    private static func read(_ json: JSONValue, raw: Data) -> [Reading] {
        guard let type = json["type"]?.stringValue else { return [] }
        guard type == "user" || type == "assistant" else { return [] }
        guard let message = json["message"] else { return [] }
        let isUser = type == "user"

        if let content = message["content"]?.stringValue {
            let body = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { return [] }
            guard !isUser else { return [.brief(body)] }
            guard let payload = oneBlockLine(json, holding: .object([
                "type": .string("text"), "text": .string(body),
            ])) else { return [] }
            return [.row(kind: .assistantText, payload: payload, refID: nil)]
        }

        let blocks = message["content"]?.arrayValue ?? []
        return blocks.compactMap { block in
            read(block: block, in: json, raw: raw, isOnlyBlock: blocks.count == 1, isUser: isUser)
        }
    }

    private static func read(
        block: JSONValue, in json: JSONValue, raw: Data, isOnlyBlock: Bool, isUser: Bool
    ) -> Reading? {
        func payload() -> Data? {
            isOnlyBlock ? raw : oneBlockLine(json, holding: block)
        }

        switch block["type"]?.stringValue {
        case "text":
            let body = (block["text"]?.stringValue ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { return nil }
            guard !isUser else { return .brief(body) }
            guard let payload = payload() else { return nil }
            return .row(kind: .assistantText, payload: payload, refID: nil)

        case "thinking":
            let thought = (block["thinking"]?.stringValue ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !isUser, !thought.isEmpty, let payload = payload() else { return nil }
            return .row(kind: .thinking, payload: payload, refID: nil)

        case "tool_use":
            guard !isUser, let payload = payload() else { return nil }
            return .row(kind: .toolUse, payload: payload, refID: block["id"]?.stringValue)

        case "tool_result":
            guard let payload = payload() else { return nil }
            return .row(kind: .toolResult, payload: payload, refID: block["tool_use_id"]?.stringValue)

        default:
            return nil
        }
    }

    private static func oneBlockLine(_ json: JSONValue, holding block: JSONValue) -> Data? {
        guard case .object(var top) = json, case .object(var message)? = json["message"] else {
            return nil
        }
        message["content"] = .array([block])
        top["message"] = .object(message)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return try? encoder.encode(JSONValue.object(top))
    }
}

public enum SubagentOutput: Sendable {
    public enum Failure: Error, Sendable, Hashable {
        case noFile
        case missing
        case unreadable(String)
    }

    public static let tailBytes = 256 * 1024

    public static func read(path: String?, kind: SubagentKind = .agent, sessionID: SessionID)
        -> Result<SubagentTranscript, Failure> {
        guard let path, !path.isEmpty else { return .failure(.noFile) }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { return .failure(.missing) }
        do {
            let text = try tail(of: url)
            return .success(kind.writesTranscript
                ? SubagentTranscript.parse(text, sessionID: sessionID)
                : SubagentTranscript.command(text))
        } catch {
            return .failure(.unreadable(error.localizedDescription))
        }
    }

    static func tail(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let size = Int(try handle.seekToEnd())
        guard size > tailBytes else {
            try handle.seek(toOffset: 0)
            let data = try handle.readToEnd() ?? Data()
            return String(decoding: data, as: UTF8.self)
        }
        try handle.seek(toOffset: UInt64(size - tailBytes))
        let data = try handle.readToEnd() ?? Data()
        let text = String(decoding: data, as: UTF8.self)
        guard let newline = text.firstIndex(where: \.isNewline) else { return text }
        return String(text[text.index(after: newline)...])
    }
}

extension SubagentOutput.Failure {
    public func sentence(_ kind: SubagentKind = .agent) -> String {
        switch (self, kind) {
        case (.noFile, .agent):
            "The agent did not say where this subagent's output was written."
        case (.noFile, .command):
            "The agent did not capture this command's output, so there is nothing to show."
        case (.missing, .agent):
            "The agent has not written this subagent's output yet."
        case (.missing, .command):
            "This command has not printed anything yet."
        case (.unreadable(let reason), _):
            "This \(kind.noun)'s output could not be read. \(reason)"
        }
    }
}
