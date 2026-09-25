import Foundation

public enum ClaudeModelRank {
    static let families = ["fable", "opus", "sonnet", "haiku"]

    static let windows = ["1m", "200k"]

    public static func ordered(_ ids: [String]) -> [String] {
        ids.enumerated()
            .sorted { left, right in
                let a = key(left.element)
                let b = key(right.element)
                if a.family != b.family { return a.family < b.family }
                if a.namesVersion != b.namesVersion { return !a.namesVersion }
                if a.version != b.version { return a.version.isAbove(b.version) }
                if a.window != b.window { return a.window < b.window }
                return left.offset < right.offset
            }
            .map(\.element)
    }

    public static func recognises(_ id: String) -> Bool {
        let value = id.lowercased()
        if key(value).family < families.count { return true }
        if families.contains(where: value.hasPrefix) { return true }
        guard value.hasPrefix("claude-") else { return false }
        let rest = value.dropFirst("claude-".count)
        return rest.contains(where: \.isLetter) && rest.contains(where: \.isNumber)
    }

    struct Key {
        var family: Int
        var namesVersion: Bool
        var version: Version
        var window: Int
    }

    static func key(_ id: String) -> Key {
        let parts = tokens(of: id)
        let family = families.firstIndex { parts.contains($0) } ?? families.count
        let version = version(after: family, in: parts)

        return Key(
            family: family,
            namesVersion: version != nil,
            version: version ?? Version(),
            window: window(in: parts)
        )
    }

    static func tokens(of id: String) -> [String] {
        id.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    static func version(after family: Int, in parts: [String]) -> Version? {
        guard family < families.count,
              let start = parts.firstIndex(of: families[family]) else { return nil }

        let rest = parts[parts.index(after: start)...]
        guard let major = rest.first.flatMap(digits) else { return nil }

        let minor = rest.dropFirst().first.flatMap(digits) ?? 0
        return Version(major: major, minor: minor)
    }

    static func window(in parts: [String]) -> Int {
        for (index, marker) in windows.enumerated() where parts.contains(marker) {
            return index + 1
        }
        return 0
    }

    static func digits(_ part: String) -> Int? {
        guard !part.isEmpty, part.allSatisfy(\.isNumber) else { return nil }
        return Int(part)
    }

    struct Version: Equatable {
        var major = 0
        var minor = 0

        func isAbove(_ other: Version) -> Bool {
            major == other.major ? minor > other.minor : major > other.major
        }
    }
}
