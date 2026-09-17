import Foundation

public enum ChatCloseCommand {
    public static func matches(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines) == "/close"
    }
}
