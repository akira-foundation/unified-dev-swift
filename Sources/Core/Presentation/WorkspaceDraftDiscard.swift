import Foundation

public enum WorkspaceDraftDiscard: Equatable, Sendable {
    case ignore
    case discard
    case confirm

    public static let title = "Discard this draft?"
    public static let message = "What you wrote for this workspace goes, and it cannot be brought back."
    public static let confirmLabel = "Discard Draft"
    public static let cancelLabel = "Keep Writing"

    public static func onEscape(hasContent: Bool, isCreating: Bool) -> Self {
        guard !isCreating else { return .ignore }
        return hasContent ? .confirm : .discard
    }
}
