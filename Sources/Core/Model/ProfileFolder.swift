import Foundation

public enum ProfileFolder {
    public static func name(for profileName: String, taken: Set<String>) -> String {
        let base = slug(profileName)
        guard taken.contains(base) else { return base }
        var number = 2
        while taken.contains("\(base)-\(number)") { number += 1 }
        return "\(base)-\(number)"
    }

    private static func slug(_ name: String) -> String {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        let mapped = folded.unicodeScalars.map { scalar -> Character in
            let isUsable = (scalar >= "a" && scalar <= "z") || (scalar >= "0" && scalar <= "9")
            return isUsable ? Character(scalar) : "-"
        }
        let parts = String(mapped).split(separator: "-", omittingEmptySubsequences: true)
        return parts.isEmpty ? "profile" : parts.joined(separator: "-")
    }
}
