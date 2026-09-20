import Foundation

public enum CrewNaming {
    public static let fallback = "suggested"

    public static func free(for title: String, existing: Set<String>) -> String {
        let base = Crew.normalisedName(title) ?? fallback
        guard existing.contains(base) else { return base }
        var number = 2
        while true {
            let suffix = " \(number)"
            let stem = base.prefix(Crew.nameLimit - suffix.count).trimmingCharacters(in: .whitespaces)
            let candidate = stem + suffix
            if !existing.contains(candidate) { return candidate }
            number += 1
        }
    }
}
