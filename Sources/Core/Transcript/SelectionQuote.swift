import Foundation

public enum SelectionQuote {
    public static func quote(_ selection: String) -> String? {
        let text = selection.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                let line = line.trimmingCharacters(in: .whitespaces)
                return line.isEmpty ? ">" : "> " + line
            }
            .joined(separator: "\n")
    }

    public static func appending(_ quote: String, to draft: String) -> String {
        var head = draft
        while head.last?.isNewline == true { head.removeLast() }
        return (head.isEmpty ? "" : head + "\n\n") + quote + "\n\n"
    }
}

public enum SelectionActions {
    public static func accepts(_ kind: MessageKind) -> Bool {
        kind == .user || kind == .assistantText
    }

    public static func canBranch(isAsk: Bool, isSideConversation: Bool, workspaceIsActive: Bool) -> Bool {
        !isAsk && !isSideConversation && workspaceIsActive
    }
}
