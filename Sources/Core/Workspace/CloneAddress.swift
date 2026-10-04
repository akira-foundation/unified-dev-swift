import Foundation

public enum CloneAddress {
    public static let safeSchemes: Set<String> = ["https", "ssh", "file"]

    public static let webInterfaceMarkers: Set<String> = [
        "tree", "blob", "commit", "commits", "compare", "issues", "pull", "pulls",
        "releases", "tags", "wiki", "actions", "settings",
    ]

    public static func resolved(_ remote: String, home: String) -> String {
        let trimmed = remote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("~") else { return trimmed }
        return NewProjectPlan.expand(trimmed, home: home)
    }

    public static func name(of remote: String) -> String? {
        guard let path = path(of: remote), !path.isEmpty else { return nil }
        return bare((path as NSString).lastPathComponent)
    }

    static func path(of remote: String) -> String? {
        var trimmed = remote.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cut = trimmed.firstIndex(where: { $0 == "?" || $0 == "#" }) {
            trimmed = String(trimmed[trimmed.startIndex..<cut])
        }
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        guard !trimmed.isEmpty else { return nil }

        if let scheme = trimmed.range(of: "://") {
            let afterScheme = String(trimmed[scheme.upperBound...])
            guard let slash = afterScheme.firstIndex(of: "/") else { return nil }
            return String(afterScheme[afterScheme.index(after: slash)...])
        }
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") { return trimmed }
        guard let colon = trimmed.firstIndex(of: ":") else { return trimmed }
        return String(trimmed[trimmed.index(after: colon)...])
    }

    private static func bare(_ component: String) -> String? {
        var name = component
        if name.hasSuffix(".git") { name.removeLast(4) }
        guard !name.isEmpty, name != ".", name != ".." else { return nil }
        guard !name.contains("\0") else { return nil }
        return name
    }

    static func webInterfaceMarker(in remote: String) -> String? {
        guard let path = path(of: remote) else { return nil }
        let parts = path.split(separator: "/").map(String.init)
        guard parts.count > 2 else { return nil }
        return parts.dropFirst(2).first { webInterfaceMarkers.contains($0.lowercased()) }
    }

    public static func transportHelper(in remote: String) -> String? {
        guard let marker = remote.range(of: "::") else { return nil }
        let head = String(remote[remote.startIndex..<marker.lowerBound])
        guard !head.isEmpty, head.allSatisfy(isHelperCharacter) else { return nil }
        return head
    }

    private static func isHelperCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "-" || character == "+"
            || character == "."
    }

    public static func embeddedPassword(in remote: String) -> Bool {
        guard let scheme = remote.range(of: "://") else { return false }
        let afterScheme = String(remote[scheme.upperBound...])
        let authority = afterScheme.prefix { $0 != "/" }
        guard let at = authority.lastIndex(of: "@") else { return false }
        return authority[authority.startIndex..<at].contains(":")
    }

    public static func isSupported(_ remote: String) -> Bool {
        if remote.hasPrefix("/") || remote.hasPrefix("~") { return true }
        if let scheme = remote.range(of: "://") {
            let named = String(remote[remote.startIndex..<scheme.lowerBound]).lowercased()
            return safeSchemes.contains(named)
        }
        guard let colon = remote.firstIndex(of: ":") else { return false }
        let host = String(remote[remote.startIndex..<colon])
        return !host.isEmpty && !host.contains("/") && remote.index(after: colon) < remote.endIndex
    }
}
