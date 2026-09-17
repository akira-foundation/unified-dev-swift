import Foundation

public enum UserTurnPrompt {
    public static let summaryLimit = 180

    public static func text(in payload: Data) -> String {
        let content = JSONValue.parse(payload)?["message"]?["content"]
        if let text = content?.stringValue { return text }
        guard let blocks = content?.arrayValue else {
            return ""
        }
        return blocks.compactMap { $0["text"]?.stringValue }.joined(separator: "\n")
    }

    public static func summary(in payload: Data, limit: Int = summaryLimit) -> String? {
        summary(of: text(in: payload), limit: limit)
    }

    public static func summary(of text: String, limit: Int = summaryLimit) -> String? {
        let presented = SentTurn.withoutInstructions(text)
        let visible: String
        if let review = ReviewTurn.split(presented) {
            visible = if review.message.isEmpty {
                Counted.of(review.chips.count, "review comment")
            } else {
                review.message
            }
        } else {
            let turn = AttachmentTrailer.split(presented)
            if !turn.body.isEmpty {
                visible = turn.body
            } else if turn.paths.count == 1, let path = turn.paths.first {
                visible = "Attached \(URL(fileURLWithPath: path).lastPathComponent)"
            } else if !turn.paths.isEmpty {
                visible = "\(turn.paths.count) attachments"
            } else {
                visible = presented
            }
        }

        let oneLine = visible.split(whereSeparator: \Character.isWhitespace).joined(separator: " ")
        guard !oneLine.isEmpty else { return nil }
        let cap = max(1, limit)
        guard oneLine.count > cap else { return oneLine }
        return String(oneLine.prefix(cap)).trimmingCharacters(in: .whitespaces) + "…"
    }
}
