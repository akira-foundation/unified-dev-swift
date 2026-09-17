import Foundation

public enum CodexModelRank {
    static let reduced = ["mini", "nano", "spark", "lite", "small"]

    public static func ordered(_ models: [CodexModel]) -> [CodexModel] {
        models.enumerated()
            .sorted { left, right in
                let a = key(left.element)
                let b = key(right.element)
                if a.version != b.version { return a.version.isAbove(b.version) }
                if a.isReduced != b.isReduced { return !a.isReduced }
                return left.offset < right.offset
            }
            .map(\.element)
    }

    static func key(_ model: CodexModel) -> (version: Version, isReduced: Bool) {
        (version(of: model.id), isReduced(model.id))
    }

    struct Version: Equatable {
        var major = 0
        var minor = 0

        func isAbove(_ other: Version) -> Bool {
            major == other.major ? minor > other.minor : major > other.major
        }
    }

    static func version(of id: String) -> Version {
        let digits = id.lowercased().drop { !$0.isNumber }
        var seenDot = false
        let text = digits.prefix {
            if $0.isNumber { return true }
            if $0 == ".", !seenDot { seenDot = true; return true }
            return false
        }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        return Version(
            major: parts.first.flatMap { Int($0) } ?? 0,
            minor: parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
        )
    }

    static func isReduced(_ id: String) -> Bool {
        let words = id.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
        return words.contains { reduced.contains($0) }
    }
}
