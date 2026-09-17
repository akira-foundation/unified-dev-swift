import Foundation

extension Git {
    private static let prefixEdges = CharacterSet.whitespacesAndNewlines
        .union(CharacterSet(charactersIn: "/"))

    private static let stopWords: Set<String> = [
        "the", "a", "an", "and", "or", "but", "to", "of", "in", "on", "for", "with",
        "please", "can", "you", "i", "we", "it", "this", "that", "is", "are", "be",
        "should", "would", "could", "make", "let", "lets",
    ]

    public static func slug(from prompt: String, maxWords: Int = 5) -> String {
        let firstLine = prompt
            .components(separatedBy: "\n")
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? prompt

        let words = firstLine
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        var kept = words.filter { !stopWords.contains($0) && $0.count > 1 }
        if kept.isEmpty { kept = words }
        if kept.isEmpty { return "workspace" }

        var parts = Array(kept.prefix(maxWords))

        if let token = distinguishingToken(from: firstLine), !parts.contains(token) {
            parts.append(token)
        }

        return String(parts.joined(separator: "-").prefix(60))
    }

    static func distinguishingToken(from line: String) -> String? {
        let separators = CharacterSet(charactersIn: " \t,;()[]{}\"'`")
        for token in line.components(separatedBy: separators) where !token.isEmpty {
            let trimmed = token.trimmingCharacters(in: CharacterSet(charactersIn: ".:"))
            let base = (trimmed as NSString).lastPathComponent
            let stem = (base as NSString).deletingPathExtension
            let ext = (base as NSString).pathExtension

            let looksLikePath = trimmed.contains("/")
            let looksLikeFile = !ext.isEmpty && ext.count <= 5
                && ext.allSatisfy(\.isLetter) && stem.count >= 3
            guard looksLikePath || looksLikeFile else { continue }

            let cleaned = stem
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .joined(separator: "-")
            if cleaned.count >= 2 { return cleaned }
        }
        return nil
    }

    public static func title(from prompt: String, maxLength: Int = 72) -> String {
        let firstLine = prompt
            .components(separatedBy: "\n")
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !firstLine.isEmpty else { return "New workspace" }

        var title = firstLine
        if title.count > maxLength {
            let cut = title.prefix(maxLength)
            if let lastSpace = cut.lastIndex(of: " ") {
                title = String(cut[..<lastSpace])
            } else {
                title = String(cut)
            }
        }
        return title.prefix(1).uppercased() + title.dropFirst()
    }

    public static func branchStem(prompt: String, prefix: String?, branch: String? = nil) -> String {
        if let branch, !branch.isEmpty { return branch }
        return prefixed(Self.slug(from: prompt), with: prefix)
    }

    public static func prefixed(_ slug: String, with prefix: String?) -> String {
        guard let prefix else { return slug }
        let trimmed = prefix.trimmingCharacters(in: prefixEdges)
        guard !trimmed.isEmpty else { return slug }
        return "\(trimmed)/\(slug)"
    }

    public static func uniqueBranch(_ desired: String, taken: Set<String>) -> String {
        guard taken.contains(desired) else { return desired }
        var suffix = 2
        while taken.contains("\(desired)-\(suffix)") { suffix += 1 }
        return "\(desired)-\(suffix)"
    }
}
