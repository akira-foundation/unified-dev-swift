import Foundation

public struct DetectedLink: Sendable, Hashable {
    public let range: Range<String.Index>

    public let text: String

    public let url: String

    public init(range: Range<String.Index>, text: String, url: String) {
        self.range = range
        self.text = text
        self.url = url
    }
}

public enum LinkScan: Sendable {
    public static func links(in text: String) -> [DetectedLink] {
        var found: [DetectedLink] = []
        var isFenced = false

        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let opener = line.drop(while: { $0 == " " || $0 == "\t" })
            if opener.hasPrefix("```") || opener.hasPrefix("~~~") {
                isFenced.toggle()
                continue
            }
            guard !isFenced else { continue }
            scan(line, of: text, into: &found)
        }

        return found
    }

    public static func link(in text: String, at index: String.Index) -> DetectedLink? {
        guard index < text.endIndex, Self.starters.contains(text[index]) else { return nil }
        guard startsToken(text, at: index) else { return nil }

        let remainder = text[index...]
        guard let opening = opening(remainder) else { return nil }

        var end = index
        while end < text.endIndex, isAddressCharacter(text[end]) {
            end = text.index(after: end)
        }
        end = trimmingTail(text, from: index, to: end)

        guard text.distance(from: index, to: end) >= opening.required else { return nil }
        let written = String(text[index..<end])
        guard let url = absolute(opening.prefix + written) else { return nil }
        return DetectedLink(range: index..<end, text: written, url: url)
    }

    private static let starters: Set<Character> = ["h", "H", "l", "L", "1"]

    private static func scan(_ line: Substring, of text: String, into found: inout [DetectedLink]) {
        var index = line.startIndex
        while index < line.endIndex {
            if line[index] == "`" {
                index = skippingCodeSpan(line, from: index)
                continue
            }
            if let link = link(in: text, at: index) {
                found.append(link)
                index = link.range.upperBound
                continue
            }
            index = line.index(after: index)
        }
    }

    private static func skippingCodeSpan(_ line: Substring, from index: String.Index) -> String.Index {
        let count = line[index...].prefix(while: { $0 == "`" }).count
        let afterOpen = line.index(index, offsetBy: count)
        guard afterOpen < line.endIndex else { return line.endIndex }
        let marker = String(repeating: "`", count: count)
        guard let close = line.range(of: marker, range: afterOpen..<line.endIndex) else { return afterOpen }
        return close.upperBound
    }

    private static let glued: Set<Character> = ["@", "/", ".", "_", "-", "+", "~", "%"]

    private static func startsToken(_ text: String, at index: String.Index) -> Bool {
        guard index > text.startIndex else { return true }
        let previous = text[text.index(before: index)]
        if previous.isLetter || previous.isNumber { return false }
        return !glued.contains(previous)
    }

    private static func opening(_ remainder: Substring) -> (prefix: String, required: Int)? {
        for scheme in ["https://", "http://"] where matches(remainder, scheme) {
            guard let host = remainder.dropFirst(scheme.count).first, host.isLetter || host.isNumber else {
                return nil
            }
            return (prefix: "", required: scheme.count + 1)
        }

        for host in ["localhost", "127.0.0.1"] where matches(remainder, host) {
            let rest = remainder.dropFirst(host.count)
            guard rest.first == ":" else { return nil }
            let port = rest.dropFirst().prefix(while: { $0.isASCII && $0.isNumber }).count
            guard port > 0 else { return nil }
            return (prefix: "http://", required: host.count + 1 + port)
        }

        return nil
    }

    private static func matches(_ remainder: Substring, _ prefix: String) -> Bool {
        let head = remainder.prefix(prefix.count)
        return head.count == prefix.count && String(head).lowercased() == prefix
    }

    private static let wrappers: Set<Character> = [
        "<", ">", "\"", "'", "\u{2018}", "\u{2019}", "\u{201C}", "\u{201D}", "`",
    ]

    private static func isAddressCharacter(_ character: Character) -> Bool {
        !character.isWhitespace && !character.isNewline && !wrappers.contains(character)
    }

    private static let tail: Set<Character> = [".", ",", ";", ":", "!", "?"]

    private static let brackets: [Character: Character] = [")": "(", "]": "[", "}": "{"]

    private static func trimmingTail(_ text: String, from start: String.Index, to end: String.Index) -> String.Index {
        var end = end
        while end > start {
            let last = text[text.index(before: end)]
            if tail.contains(last) {
                end = text.index(before: end)
                continue
            }
            if let opener = brackets[last] {
                let body = text[start..<end]
                if body.filter({ $0 == opener }).count < body.filter({ $0 == last }).count {
                    end = text.index(before: end)
                    continue
                }
            }
            break
        }
        return end
    }

    private static func absolute(_ raw: String) -> String? {
        if isAddressable(raw) { return raw }
        guard let escaped = raw.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed),
              isAddressable(escaped) else { return nil }
        return escaped
    }

    private static func isAddressable(_ value: String) -> Bool {
        guard let url = URL(string: value), let scheme = url.scheme?.lowercased() else { return false }
        guard scheme == "http" || scheme == "https" else { return false }
        guard let host = url.host(), !host.isEmpty else { return false }
        return true
    }
}
