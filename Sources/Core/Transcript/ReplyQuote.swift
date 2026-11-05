import Foundation

public struct ReplyQuote: Identifiable, Hashable, Sendable {
    public let id: ReplyQuoteID
    public let quoted: String
    public let summary: String
    public let sourceSeq: Int?

    public init?(selection: String, sourceSeq: Int? = nil) {
        guard let quoted = SelectionQuote.quote(selection), let summary = Self.summary(of: selection) else {
            return nil
        }
        id = ReplyQuoteID(UUID().uuidString)
        self.quoted = quoted
        self.summary = summary
        self.sourceSeq = sourceSeq
    }

    public static func summary(of selection: String) -> String? {
        let summary = selection
            .replacingOccurrences(of: "\u{FFFC}", with: "")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        return summary.isEmpty ? nil : summary
    }

    init(id: ReplyQuoteID, quoted: String, summary: String, sourceSeq: Int?) {
        self.id = id
        self.quoted = quoted
        self.summary = summary
        self.sourceSeq = sourceSeq
    }

    public static func message(_ text: String, quoting quotes: [ReplyQuote]) -> String {
        guard !quotes.isEmpty else { return text }
        let block = quotes.map(\.quoted).joined(separator: "\n\n")
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.isEmpty { return block }
        return body.hasPrefix("/") ? body + "\n\n" + block : block + "\n\n" + body
    }

    public static func draft(_ draft: String, adding typed: String) -> String {
        let reply = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reply.isEmpty else { return draft }
        var head = draft
        while head.last?.isNewline == true { head.removeLast() }
        return head.isEmpty ? reply : head + "\n\n" + reply
    }
}
