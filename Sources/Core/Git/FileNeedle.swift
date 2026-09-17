import Foundation

public enum FileNeedle {
    public static func canonical(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespaces).lowercased()
    }

    public static func matches(_ candidate: String, needle: String) -> Bool {
        FuzzyMatch.score(candidate, query: needle) != nil
    }
}
