import Foundation

public enum MessageCopyText {
    public static func markdown(kind: MessageKind, payload: Data) -> String? {
        let text: String
        switch kind {
        case .user:
            text = SentTurn.withoutInstructions(UserTurnPrompt.text(in: payload))
        case .assistantText:
            let event = AgentEvent.decode(line: String(decoding: payload, as: UTF8.self))
            guard case .assistantText(let block) = event else { return nil }
            text = block.text
        default:
            return nil
        }
        return text.isEmpty ? nil : text
    }

    public static func plain(kind: MessageKind, payload: Data) -> String? {
        markdown(kind: kind, payload: payload).map(MarkdownPlainText.render)
    }
}
