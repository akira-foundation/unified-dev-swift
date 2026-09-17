import Foundation

public enum SubmittedDraft {
    public static func matching(current: String, message: String, source: String? = nil) -> String? {
        let expected = (source ?? message).trimmingCharacters(in: .whitespacesAndNewlines)
        return current.trimmingCharacters(in: .whitespacesAndNewlines) == expected ? current : nil
    }
}
