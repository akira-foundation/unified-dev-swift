import Foundation

public struct DiffEditRegion: Sendable, Hashable {
    public let firstLine: Int
    public let lines: [String]

    public init(firstLine: Int, lines: [String]) {
        self.firstLine = firstLine
        self.lines = lines
    }

    public var lineCount: Int { lines.count }
    public var lastLine: Int { firstLine + lines.count - 1 }

    public var text: String { lines.joined(separator: "\n") }

    public func isEdited(_ typed: String) -> Bool { typed != text }
}

public enum DiffEditRefusal: Error, Sendable, Equatable {
    case oldSide
    case gone(line: Int)
    case moved(line: Int)
    case tooManyLines(Int)
}

extension DiffEditRefusal: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .oldSide:
            "A removed line is not in the file any more, so there is nothing to edit."
        case let .gone(line):
            "The file does not have line \(line) any more. It has changed since this diff was drawn."
        case let .moved(line):
            "Line \(line) no longer holds what this diff shows. The file changed while you were "
                + "reading it, so nothing was opened for editing."
        case let .tooManyLines(count):
            "That is \(count) new lines in a row, more than the \(DiffEdit.lineLimit) this box "
                + "takes. Open the file itself to change something this size."
        }
    }
}

public enum DiffEdit {
    public static let lineLimit = 200

    public static func region(
        at line: Int, in hunks: [DiffHunk], fileText: String
    ) throws(DiffEditRefusal) -> DiffEditRegion {
        let contents = Contents(of: fileText)
        let printed = newSide(of: hunks)

        let covered = try span(at: line, printed: printed)
        guard covered.count <= lineLimit else { throw DiffEditRefusal.tooManyLines(covered.count) }
        guard covered.lowerBound >= 1, covered.upperBound <= contents.lines.count else {
            throw DiffEditRefusal.gone(line: covered.upperBound)
        }

        for number in covered {
            guard let shown = printed[number] else { continue }
            guard contents.lines[number - 1] == shown.text else {
                throw DiffEditRefusal.moved(line: number)
            }
        }

        return DiffEditRegion(
            firstLine: covered.lowerBound,
            lines: Array(contents.lines[(covered.lowerBound - 1)..<covered.upperBound])
        )
    }

    private static func span(
        at line: Int, printed: [Int: DiffLine]
    ) throws(DiffEditRefusal) -> ClosedRange<Int> {
        guard line >= 1 else { throw DiffEditRefusal.gone(line: line) }
        guard let target = printed[line] else { return line...line }

        switch target.kind {
        case .context:
            return line...line
        case .addition:
            var first = line
            var last = line
            while printed[first - 1]?.kind == .addition { first -= 1 }
            while printed[last + 1]?.kind == .addition { last += 1 }
            return first...last
        case .deletion, .noNewline:
            throw DiffEditRefusal.oldSide
        }
    }

    private static func newSide(of hunks: [DiffHunk]) -> [Int: DiffLine] {
        var result: [Int: DiffLine] = [:]
        for hunk in hunks {
            for line in hunk.lines where line.kind != .noNewline {
                guard let number = line.newNumber else { continue }
                result[number] = line
            }
        }
        return result
    }

    public static func apply(
        _ edited: String, of region: DiffEditRegion, to fileText: String
    ) throws(DiffEditRefusal) -> String {
        var contents = Contents(of: fileText)
        let first = region.firstLine - 1
        let last = region.lastLine - 1
        guard first >= 0, last < contents.lines.count else {
            throw DiffEditRefusal.gone(line: region.lastLine)
        }
        guard Array(contents.lines[first...last]) == region.lines else {
            throw DiffEditRefusal.moved(line: region.firstLine)
        }
        contents.lines.replaceSubrange(first...last, with: edited.components(separatedBy: "\n"))
        return contents.text
    }

    public static func staleWarning(
        filename: String, baseline: String, contents: String?
    ) -> String? {
        guard let contents else {
            return "\(filename) is no longer on disk. Saving will be refused, so copy anything "
                + "you want to keep."
        }
        guard contents != baseline else { return nil }
        return "\(filename) changed on disk while you were editing. Saving will be refused, so "
            + "copy what you typed, cancel, and edit the new version."
    }

    public enum Discard {
        public static func needed(closing typed: String, of region: DiffEditRegion) -> Bool {
            region.isEdited(typed)
        }

        public static let title = "Discard these edits?"
        public static let message = "The file is not changed, and what you typed is not kept."
        public static let confirmLabel = "Discard"
        public static let cancelLabel = "Keep Editing"
    }

    struct Contents {
        var lines: [String]
        var endsWithNewline: Bool

        init(of text: String) {
            var lines = text.components(separatedBy: "\n")
            endsWithNewline = lines.count > 1 && lines.last == ""
            if endsWithNewline { lines.removeLast() }
            self.lines = lines
        }

        var text: String {
            lines.joined(separator: "\n") + (endsWithNewline ? "\n" : "")
        }
    }
}
