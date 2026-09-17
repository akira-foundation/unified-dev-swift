import Foundation

public enum QuickPromptDeletion {
    public static func title(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Delete this quick prompt?" }
        guard trimmed.count > nameLength else { return "Delete \u{201C}\(trimmed)\u{201D}?" }
        let cut = trimmed.prefix(nameLength).trimmingCharacters(in: .whitespaces)
        return "Delete \u{201C}\(cut)\u{2026}\u{201D}?"
    }

    static let nameLength = 40

    public static let message =
        "The prompt goes from every workspace. Nothing already sent is affected, and it cannot be "
        + "brought back."

    public static let confirmLabel = "Delete Prompt"
    public static let cancelLabel = "Cancel"
}
