import Foundation

public enum TranscriptRowShape: Sendable, Hashable, CaseIterable {
    case message
    case answer
    case tool
    case footer
    case notice
    case fold
    case other

    public static func of(kind: MessageKind) -> Self {
        switch kind {
        case .user, .crew: .message
        case .assistantText, .thinking: .answer
        case .toolUse, .toolResult, .permissionAsk: .tool
        case .result: .footer
        case .error, .notice, .system, .suggestion: .notice
        }
    }
}
