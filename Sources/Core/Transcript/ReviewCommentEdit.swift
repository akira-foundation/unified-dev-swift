import Foundation

public enum ReviewCommentEdit {
    public enum Outcome: Sendable, Hashable {
        case save(String)
        case unchanged
        case refused
    }

    public static func trim(_ typed: String) -> String {
        typed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func canSubmit(_ typed: String) -> Bool {
        !trim(typed).isEmpty
    }

    public static func outcome(typed: String, replacing body: String) -> Outcome {
        let trimmed = trim(typed)
        guard !trimmed.isEmpty else { return .refused }
        guard trimmed != body else { return .unchanged }
        return .save(trimmed)
    }
}
