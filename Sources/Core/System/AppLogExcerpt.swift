import Foundation

public enum AppLogExcerpt {
    public struct Entry: Sendable, Equatable {
        public var date: Date
        public var category: String
        public var message: String

        public init(date: Date, category: String, message: String) {
            self.date = date
            self.category = category
            self.message = message
        }
    }

    public static let window: TimeInterval = 30 * 60

    public static let maxEntries = 200

    public static let maxCharacters = 20_000

    public static let maxEntryCharacters = 400

    public static let elision = "…"

    public static let empty = "Unified Dev has not written anything to its log since it started."

    public struct Word: Sendable, Equatable {
        public var text: String
        public var placeholder: String

        public init(text: String, placeholder: String) {
            self.text = text
            self.placeholder = placeholder
        }
    }

    public struct Redaction: Sendable, Equatable {
        public var words: [Word]

        public init(words: [Word] = []) {
            self.words = Redaction.ordered(words)
        }

        public static let minimumLength = 4

        public static func of(
            projects: [String] = [],
            workspaces: [String] = [],
            branches: [String] = [],
            user: String? = nil,
            host: String? = nil
        ) -> Redaction {
            var words: [Word] = []
            words += projects.map { Word(text: $0, placeholder: Placeholder.project) }
            words += workspaces.map { Word(text: $0, placeholder: Placeholder.workspace) }
            words += branches.map { Word(text: $0, placeholder: Placeholder.branch) }
            if let user { words.append(Word(text: user, placeholder: Placeholder.user)) }
            if let host { words.append(Word(text: host, placeholder: Placeholder.host)) }
            return Redaction(words: words)
        }

        static func ordered(_ words: [Word]) -> [Word] {
            var seen: Set<String> = []
            return
                words
                .map { Word(text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines), placeholder: $0.placeholder) }
                .filter { $0.text.count >= minimumLength }
                .filter { seen.insert($0.text.lowercased()).inserted }
                .sorted { $0.text.count > $1.text.count }
        }
    }

    public enum Placeholder {
        public static let secret = "<redacted>"
        public static let url = "<url>"
        public static let email = "<email>"
        public static let path = "<path>"
        public static let project = "<project>"
        public static let workspace = "<workspace>"
        public static let branch = "<branch>"
        public static let user = "<user>"
        public static let host = "<host>"
    }

    public static func excerpt(
        _ entries: [Entry],
        since: Date? = nil,
        redaction: Redaction = Redaction(),
        timeZone: TimeZone = .current
    ) -> String {
        let kept = entries
            .filter { entry in since.map { entry.date >= $0 } ?? true }
            .suffix(maxEntries)

        let lines = kept.map { line($0, redaction: redaction, timeZone: timeZone) }
        guard !lines.isEmpty else { return empty }

        return capped(lines.joined(separator: "\n"))
    }

    public static func line(
        _ entry: Entry,
        redaction: Redaction = Redaction(),
        timeZone: TimeZone = .current
    ) -> String {
        let message = truncated(
            folded(scrubbed(entry.message, redaction: redaction)),
            to: maxEntryCharacters
        )
        let category = truncated(folded(entry.category), to: 32)
        return "\(time(entry.date, in: timeZone))  \(category)  \(message)"
    }

    public static func scrubbed(_ text: String, redaction: Redaction = Redaction()) -> String {
        var result = text

        for rule in credentialPatterns + shapePatterns + [catchAll] {
            result = result.replacingOccurrences(
                of: rule.pattern, with: rule.template, options: [.regularExpression]
            )
        }

        for word in redaction.words {
            result = result.replacingOccurrences(
                of: word.text, with: word.placeholder, options: [.caseInsensitive]
            )
        }

        return result
    }

    static let credentialPatterns: [(pattern: String, template: String)] = [
        (#"-----BEGIN[^-]{0,64}-----"#, Placeholder.secret),
        (#"\beyJ[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{4,}"#, Placeholder.secret),
        (#"(?i)\b(?:sk|pk|rk)-[A-Za-z0-9_-]{12,}"#, Placeholder.secret),
        (#"\b(?:gh[pousr]_|github_pat_)[A-Za-z0-9_]{16,}"#, Placeholder.secret),
        (#"\bxox[abprs]-[A-Za-z0-9-]{10,}"#, Placeholder.secret),
        (#"\bAKIA[0-9A-Z]{16}\b"#, Placeholder.secret),
        (#"\bAIza[0-9A-Za-z_-]{16,}"#, Placeholder.secret),
        (
            #"(?i)\b(authorization|bearer|token|secret|password|passwd|api[_-]?key|apikey|access[_-]?key|private[_-]?key)\b["']?\s*[:=]?\s*\S+"#,
            "$1 " + Placeholder.secret
        ),
    ]

    static let catchAll: (pattern: String, template: String) =
        (#"[A-Za-z0-9+/_-]{40,}={0,2}"#, Placeholder.secret)

    static let shapePatterns: [(pattern: String, template: String)] = [
        (#"[a-zA-Z][a-zA-Z0-9+.-]{1,20}://[^\s'"]+"#, Placeholder.url),
        (#"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,24}"#, Placeholder.email),
        (#"~(?:/[A-Za-z0-9._+-]+)+"#, Placeholder.path),
        (#"(?<![A-Za-z0-9._~-])(?:/[A-Za-z0-9._+-]+){2,}"#, Placeholder.path),
    ]

    static func capped(_ text: String) -> String {
        guard text.count > maxCharacters else { return text }

        let tail = String(text.suffix(maxCharacters))
        guard let firstBreak = tail.firstIndex(of: "\n") else {
            return "\(elision)\n\(tail)"
        }
        return "\(elision)\n\(tail[tail.index(after: firstBreak)...])"
    }

    static func truncated(_ text: String, to limit: Int) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit)) + elision
    }

    static func folded(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: [.regularExpression])
            .trimmingCharacters(in: .whitespaces)
    }

    static func time(_ date: Date, in timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
