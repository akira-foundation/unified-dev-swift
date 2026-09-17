import Foundation

public enum ChatClearCommand {
    public static func matches(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines) == "/clear"
    }
}
