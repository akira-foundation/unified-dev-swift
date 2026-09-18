import Foundation

public struct AttachmentDraft: Equatable, Sendable {
    public enum Segment: Equatable, Sendable {
        case text(String)
        case attachment(String)

        public var text: String {
            switch self {
            case .text(let text): text
            case .attachment(let path): AttachmentDraft.token(for: path)
            }
        }
    }

    public var segments: [Segment]

    public init(segments: [Segment]) {
        self.segments = segments
    }

    public var text: String {
        segments.map(\.text).joined()
    }

    public var paths: [String] {
        segments.compactMap { segment in
            guard case .attachment(let path) = segment else { return nil }
            return path
        }
    }

    public static func token(for path: String) -> String { "`\(path)`" }

    public static let copyPrefix = WorktreeScratch.attachments + "/"

    public static func parse(
        _ draft: String, paths: [String] = [], alsoNaming: (String) -> Bool = { _ in false }
    ) -> AttachmentDraft {
        let known = Set(paths)
        var segments: [Segment] = []
        var pending = ""
        var index = draft.startIndex

        func flush() {
            guard !pending.isEmpty else { return }
            segments.append(.text(pending))
            pending = ""
        }

        while index < draft.endIndex {
            guard draft[index] == "`" else {
                pending.append(draft[index])
                index = draft.index(after: index)
                continue
            }

            let contentStart = draft.index(after: index)
            guard let closing = draft[contentStart...].firstIndex(of: "`") else {
                pending.append(contentsOf: draft[index...])
                index = draft.endIndex
                break
            }

            let content = String(draft[contentStart..<closing])
            guard isAttachment(content, known: known) || alsoNaming(content) else {
                pending.append("`")
                index = contentStart
                continue
            }

            flush()
            segments.append(.attachment(content))
            index = draft.index(after: closing)
        }

        flush()
        return AttachmentDraft(segments: segments)
    }

    public static func unnamed(_ held: [String], in draft: String) -> [String] {
        let named = Set(parse(draft, paths: held).paths)
        return held.filter { !named.contains($0) }
    }

    public static let folder = ".unifieddev/"

    public static func isAttachment(_ content: String, known: Set<String> = []) -> Bool {
        guard !content.isEmpty, !content.contains("\n") else { return false }
        if known.contains(content) { return true }

        guard content.hasPrefix(folder), !content.hasSuffix("/") else { return false }

        guard content.hasPrefix(copyPrefix) else { return true }
        let rest = content.dropFirst(copyPrefix.count)
        guard let slash = rest.firstIndex(of: "/") else { return false }
        return slash != rest.startIndex && rest.index(after: slash) != rest.endIndex
    }

    public struct Insertion: Equatable, Sendable {
        public var text: String
        public var caret: Int
    }

    public static func inserting(
        _ path: String, into draft: String, at offset: Int
    ) -> Insertion {
        let string = draft as NSString
        let at = min(max(offset, 0), string.length)

        let before = at > 0 ? string.substring(with: NSRange(location: at - 1, length: 1)) : ""
        let after = at < string.length
            ? string.substring(with: NSRange(location: at, length: 1))
            : ""

        let (lead, trail) = padding(before: before, after: after)
        let written = lead + token(for: path) + trail

        let text = string.replacingCharacters(in: NSRange(location: at, length: 0), with: written)
        return Insertion(text: text, caret: at + (written as NSString).length)
    }

    public static func inserting(
        _ paths: [String], into draft: String, at offset: Int
    ) -> Insertion {
        var result = Insertion(text: draft, caret: min(max(offset, 0), (draft as NSString).length))
        for path in paths {
            result = inserting(path, into: result.text, at: result.caret)
        }
        return result
    }

    public static func padding(before: String, after: String) -> (lead: String, trail: String) {
        (
            before.isEmpty || isBreak(before) ? "" : " ",
            isBreak(after) && !after.isEmpty ? "" : " "
        )
    }

    private static func isBreak(_ character: String) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return true }
        return CharacterSet.whitespacesAndNewlines.contains(scalar)
    }

    public func keeping(_ isKept: (String) -> Bool) -> String {
        var result = ""
        var dropsLeadingSpace = false

        for segment in segments {
            switch segment {
            case .text(var text):
                if dropsLeadingSpace, text.hasPrefix(" ") { text.removeFirst() }
                dropsLeadingSpace = false
                result += text
            case .attachment(let path):
                guard !isKept(path) else {
                    result += segment.text
                    continue
                }
                if result.hasSuffix(" ") {
                    result.removeLast()
                } else {
                    dropsLeadingSpace = true
                }
            }
        }
        return result
    }

    public func attachment(startingAt offset: Int) -> Int? {
        var seen = 0
        var location = 0
        for segment in segments {
            let length = (segment.text as NSString).length
            if case .attachment = segment {
                if location == offset { return seen }
                seen += 1
            }
            location += length
        }
        return nil
    }

    public func removal(ofAttachment occurrence: Int) -> NSRange? {
        let string = text as NSString
        var seen = 0
        var location = 0

        for segment in segments {
            let length = (segment.text as NSString).length
            guard case .attachment = segment, seen == occurrence else {
                if case .attachment = segment { seen += 1 }
                location += length
                continue
            }
            return Self.widenedOverOneSpace(NSRange(location: location, length: length), in: string)
        }
        return nil
    }

    private static func widenedOverOneSpace(_ range: NSRange, in string: NSString) -> NSRange {
        if range.location > 0,
           string.substring(with: NSRange(location: range.location - 1, length: 1)) == " " {
            return NSRange(location: range.location - 1, length: range.length + 1)
        }
        guard range.upperBound < string.length,
              string.substring(with: NSRange(location: range.upperBound, length: 1)) == " "
        else { return range }
        return NSRange(location: range.location, length: range.length + 1)
    }

    public func removing(attachment occurrence: Int) -> String {
        guard let range = removal(ofAttachment: occurrence) else { return text }
        return (text as NSString).replacingCharacters(in: range, with: "")
    }

    public static func withoutAttachments(_ draft: String, paths: [String] = []) -> String {
        parse(draft, paths: paths)
            .keeping { _ in false }
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
