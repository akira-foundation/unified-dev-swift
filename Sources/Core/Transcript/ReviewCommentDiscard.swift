import Foundation

public enum ReviewCommentDiscard: Equatable, Sendable {
    case writing
    case rewriting

    public static func needed(closing typed: String, replacing body: String?) -> Self? {
        guard ReviewCommentEdit.canSubmit(typed) else { return nil }
        guard let body else { return .writing }
        return ReviewCommentEdit.trim(typed) == ReviewCommentEdit.trim(body) ? nil : .rewriting
    }

    public var title: String {
        switch self {
        case .writing: "Discard this comment?"
        case .rewriting: "Discard this rewrite?"
        }
    }

    public var message: String {
        switch self {
        case .writing:
            "It is not added to the review, and its text is not kept."
        case .rewriting:
            "The comment keeps the text it already had, and the rewrite is not kept."
        }
    }

    public var confirmLabel: String { "Discard" }

    public var cancelLabel: String {
        switch self {
        case .writing: "Keep Writing"
        case .rewriting: "Keep Editing"
        }
    }
}
