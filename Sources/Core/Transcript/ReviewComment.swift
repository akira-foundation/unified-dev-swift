import Foundation

public enum ReviewCommentSide: String, Sendable, Hashable, CaseIterable, Codable {
    case old
    case new
}

public struct ReviewCommentAnchor: Sendable, Hashable, Codable {
    public static let contextRadius = 3

    public var line: Int
    public var text: String
    public var before: [String]
    public var after: [String]
    public var span: Int

    public init(
        line: Int,
        text: String,
        before: [String] = [],
        after: [String] = [],
        span: Int = 1
    ) {
        self.line = line
        self.text = text
        self.before = before
        self.after = after
        self.span = max(1, span)
    }

    public var lastLine: Int { line + span - 1 }

    public var isRange: Bool { span > 1 }

    public static func make(
        line: Int,
        span: Int = 1,
        in lines: [String],
        radius: Int = contextRadius
    ) -> ReviewCommentAnchor {
        let index = line - 1
        guard lines.indices.contains(index) else {
            return ReviewCommentAnchor(line: line, text: "", span: span)
        }
        let start = max(0, index - radius)
        let end = min(lines.count, index + 1 + radius)
        return ReviewCommentAnchor(
            line: line,
            text: lines[index],
            before: Array(lines[start..<index]),
            after: Array(lines[(index + 1)..<end]),
            span: span
        )
    }

    public static func make(
        line: Int,
        span: Int = 1,
        side: ReviewCommentSide,
        in hunk: DiffHunk,
        radius: Int = contextRadius
    ) -> ReviewCommentAnchor? {
        let sideLines = hunk.lines.filter { $0.kind != .noNewline && number(of: $0, on: side) != nil }
        guard let index = sideLines.firstIndex(where: { number(of: $0, on: side) == line }) else {
            return nil
        }
        let start = max(0, index - radius)
        let end = min(sideLines.count, index + 1 + radius)
        return ReviewCommentAnchor(
            line: line,
            text: sideLines[index].text,
            before: sideLines[start..<index].map(\.text),
            after: sideLines[(index + 1)..<end].map(\.text),
            span: span
        )
    }

    private static func number(of diffLine: DiffLine, on side: ReviewCommentSide) -> Int? {
        side == .old ? diffLine.oldNumber : diffLine.newNumber
    }
}

public struct AnchorResolution: Sendable, Hashable {
    public enum Status: String, Sendable, Hashable {
        case exact
        case shifted
        case outdated
    }

    public var line: Int
    public var status: Status

    public var isOutdated: Bool { status == .outdated }

    public init(line: Int, status: Status) {
        self.line = line
        self.status = status
    }
}

public extension ReviewCommentAnchor {
    func resolve(in lines: [String]) -> AnchorResolution {
        let clamped = max(1, min(line, max(lines.count, 1)))

        var candidates: [Int] = []
        for (index, current) in lines.enumerated() where current == text {
            candidates.append(index + 1)
        }
        guard !candidates.isEmpty else {
            return AnchorResolution(line: clamped, status: .outdated)
        }

        if candidates.contains(line) {
            return AnchorResolution(line: line, status: .exact)
        }

        var best = candidates[0]
        var bestScore = contextScore(at: best, in: lines)
        for candidate in candidates.dropFirst() {
            let score = contextScore(at: candidate, in: lines)
            let closer = abs(candidate - line) < abs(best - line)
            if score > bestScore || (score == bestScore && closer) {
                best = candidate
                bestScore = score
            }
        }

        if bestScore == 0, candidates.count > 1 {
            return AnchorResolution(line: clamped, status: .outdated)
        }

        return AnchorResolution(line: best, status: .shifted)
    }

    func resolve(in contents: String) -> AnchorResolution {
        resolve(in: ReviewCommentAnchor.split(contents))
    }

    static func split(_ contents: String) -> [String] {
        var lines = contents.components(separatedBy: "\n")
        if lines.count > 1, lines.last == "" { lines.removeLast() }
        return lines
    }

    private func contextScore(at candidate: Int, in lines: [String]) -> Int {
        var score = 0
        let radius = max(before.count, after.count)

        for (offset, expected) in before.reversed().enumerated() {
            let index = candidate - 2 - offset
            guard lines.indices.contains(index), lines[index] == expected else { continue }
            score += radius - offset
        }
        for (offset, expected) in after.enumerated() {
            let index = candidate + offset
            guard lines.indices.contains(index), lines[index] == expected else { continue }
            score += radius - offset
        }
        return score
    }
}

public struct ReviewComment: Identifiable, Sendable, Hashable, Codable {
    public var id: ReviewCommentID
    public var workspaceID: WorkspaceID
    public var filePath: String
    public var side: ReviewCommentSide
    public var anchor: ReviewCommentAnchor
    public var body: String
    public var createdAt: Date
    public var isAttached: Bool

    public var line: Int { anchor.line }
    public var lastLine: Int { anchor.lastLine }

    public var fileName: String { (filePath as NSString).lastPathComponent }

    public init(
        id: ReviewCommentID = .new(),
        workspaceID: WorkspaceID,
        filePath: String,
        side: ReviewCommentSide = .new,
        anchor: ReviewCommentAnchor,
        body: String,
        createdAt: Date = Date(),
        isAttached: Bool = true
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.filePath = filePath
        self.side = side
        self.anchor = anchor
        self.body = body
        self.createdAt = createdAt
        self.isAttached = isAttached
    }
}

public extension Array where Element == ReviewComment {
    func sortedForReview() -> [ReviewComment] {
        sorted {
            if $0.filePath != $1.filePath { return $0.filePath < $1.filePath }
            if $0.anchor.line != $1.anchor.line { return $0.anchor.line < $1.anchor.line }
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id < $1.id
        }
    }
}

public enum ReviewCommentSummary {
    public static let lineLimit = 3

    public static func chip(for comment: ReviewComment) -> String {
        "\(comment.fileName) \(mark(for: comment))"
    }

    public static func mark(for comment: ReviewComment) -> String {
        let sign = comment.side == .old ? "-" : "+"
        guard comment.anchor.isRange else { return "\(sign)\(comment.anchor.line)" }
        return "\(sign)\(comment.anchor.line)…\(comment.anchor.lastLine)"
    }

    public static func label(for comments: [ReviewComment]) -> String {
        let ordered = comments.sortedForReview()
        guard let first = ordered.first else { return "" }
        guard ordered.count > 1 else { return chip(for: first) }

        let sameFile = ordered.allSatisfy { $0.filePath == first.filePath }
        if sameFile, ordered.count <= lineLimit {
            return "\(first.fileName) \(ordered.map(mark(for:)).joined(separator: " "))"
        }

        return "\(chip(for: first)) and \(ordered.count - 1) more"
    }
}
