import Foundation

public struct ReviewCommentRender: Sendable, Hashable {
    public struct SnippetLine: Sendable, Hashable {
        public var number: Int
        public var text: String
        public var isAnchor: Bool

        public init(number: Int, text: String, isAnchor: Bool) {
            self.number = number
            self.text = text
            self.isAnchor = isAnchor
        }
    }

    public var comment: ReviewComment
    public var resolution: AnchorResolution
    public var snippet: [SnippetLine]

    public init(comment: ReviewComment, resolution: AnchorResolution, snippet: [SnippetLine]) {
        self.comment = comment
        self.resolution = resolution
        self.snippet = snippet
    }
}

public enum ReviewPayload {
    public static let commentLimit = 60

    public static let snippetRadius = ReviewCommentAnchor.contextRadius

    public static func worktreeReader(root: String) -> (String) -> [String]? {
        { path in
            let full = (root as NSString).appendingPathComponent(path)
            guard let contents = try? String(contentsOfFile: full, encoding: .utf8) else { return nil }
            return ReviewCommentAnchor.split(contents)
        }
    }

    public static func renders(
        for comments: [ReviewComment],
        currentLines: (String) -> [String]? = { _ in nil }
    ) -> [ReviewCommentRender] {
        var cache: [String: [String]?] = [:]
        return comments.sortedForReview().map { comment in
            let lines: [String]?
            if let known = cache[comment.filePath] {
                lines = known
            } else {
                lines = currentLines(comment.filePath)
                cache[comment.filePath] = lines
            }
            return render(comment, in: lines)
        }
    }

    public static func text(
        for comments: [ReviewComment],
        currentLines: (String) -> [String]? = { _ in nil },
        limit: Int = commentLimit
    ) -> String {
        let all = renders(for: comments, currentLines: currentLines)
        let shown = Array(all.prefix(limit))
        guard !shown.isEmpty else { return "" }

        var blocks: [String] = []
        var currentFile: String?

        for render in shown {
            let comment = render.comment
            if comment.filePath != currentFile {
                blocks.append("## \(comment.filePath)")
                currentFile = comment.filePath
            }
            blocks.append(block(for: render))
        }

        let remaining = all.count - shown.count
        if remaining > 0 {
            blocks.append(
                "...and \(remaining) \(Counted.word(remaining, "more comment")) not shown."
            )
        }
        return blocks.joined(separator: "\n\n")
    }

    private static func block(for render: ReviewCommentRender) -> String {
        let comment = render.comment
        var parts = ["### \(heading(for: render))\(sideSuffix(comment.side))"]

        if let note = provenance(for: render) { parts.append(note) }
        if let snippet = fenced(render.snippet) { parts.append(snippet) }

        parts.append(comment.body)
        return parts.joined(separator: "\n\n")
    }

    static func heading(for render: ReviewCommentRender) -> String {
        let start = render.resolution.line
        let span = render.comment.anchor.span
        return span > 1 ? "Lines \(start) to \(start + span - 1)" : "Line \(start)"
    }

    private static func provenance(for render: ReviewCommentRender) -> String? {
        let anchor = render.comment.anchor
        let original = anchor.line
        switch render.resolution.status {
        case .exact:
            return nil
        case .shifted:
            guard render.resolution.line != original else {
                return "(this file could not be read just now, so the code below is how it looked "
                    + "when the comment was written)"
            }
            guard anchor.isRange else {
                return "(this line has moved since the comment was written: it was line "
                    + "\(original))"
            }
            return "(these lines have moved since the comment was written: they were lines "
                + "\(original) to \(anchor.lastLine))"
        case .outdated:
            guard anchor.isRange else {
                return "(the file has changed and this exact line is gone; it was line \(original) "
                    + "when the comment was written, and the code below is how it looked then)"
            }
            return "(the file has changed and these exact lines are gone; they were lines "
                + "\(original) to \(anchor.lastLine) when the comment was written, and the code "
                + "below is how they looked then)"
        }
    }

    private static func sideSuffix(_ side: ReviewCommentSide) -> String {
        side == .old ? ", on the removed side of the diff" : ""
    }

    private static func fenced(_ lines: [ReviewCommentRender.SnippetLine]) -> String? {
        guard !lines.isEmpty else { return nil }

        let width = String(lines.map(\.number).max() ?? 0).count
        let body = lines.map { line in
            let number = String(line.number)
            let padded = String(repeating: " ", count: max(0, width - number.count)) + number
            let prefix = "\(line.isAnchor ? ">" : " ") \(padded) |"
            return line.text.isEmpty ? prefix : "\(prefix) \(line.text)"
        }.joined(separator: "\n")

        var longestRun = 0
        var run = 0
        for character in body {
            run = character == "`" ? run + 1 : 0
            longestRun = max(longestRun, run)
        }
        let fence = String(repeating: "`", count: max(3, longestRun + 1))
        return "\(fence)\n\(body)\n\(fence)"
    }

    private static func render(_ comment: ReviewComment, in lines: [String]?) -> ReviewCommentRender {
        guard let lines, !lines.isEmpty else {
            return ReviewCommentRender(
                comment: comment,
                resolution: AnchorResolution(line: comment.anchor.line, status: .shifted),
                snippet: storedSnippet(comment.anchor)
            )
        }

        let resolution = comment.anchor.resolve(in: lines)
        let snippet: [ReviewCommentRender.SnippetLine] = resolution.isOutdated
            ? storedSnippet(comment.anchor)
            : liveSnippet(around: resolution.line, span: comment.anchor.span, in: lines)
        return ReviewCommentRender(comment: comment, resolution: resolution, snippet: snippet)
    }

    private static func liveSnippet(
        around line: Int,
        span: Int,
        in lines: [String]
    ) -> [ReviewCommentRender.SnippetLine] {
        let index = line - 1
        guard lines.indices.contains(index) else { return [] }
        let last = min(lines.count - 1, index + max(1, span) - 1)
        let start = max(0, index - snippetRadius)
        let end = min(lines.count - 1, last + snippetRadius)
        return (start...end).map {
            ReviewCommentRender.SnippetLine(
                number: $0 + 1, text: lines[$0], isAnchor: $0 >= index && $0 <= last
            )
        }
    }

    private static func storedSnippet(
        _ anchor: ReviewCommentAnchor
    ) -> [ReviewCommentRender.SnippetLine] {
        var lines: [ReviewCommentRender.SnippetLine] = []
        for (offset, text) in anchor.before.enumerated() {
            let number = anchor.line - anchor.before.count + offset
            guard number > 0 else { continue }
            lines.append(ReviewCommentRender.SnippetLine(number: number, text: text, isAnchor: false))
        }
        lines.append(
            ReviewCommentRender.SnippetLine(number: anchor.line, text: anchor.text, isAnchor: true)
        )
        for (offset, text) in anchor.after.enumerated() {
            let number = anchor.line + 1 + offset
            lines.append(ReviewCommentRender.SnippetLine(
                number: number, text: text, isAnchor: number <= anchor.lastLine
            ))
        }
        return lines
    }
}

public struct ReviewPromptContext: Sendable, Hashable {
    public static let noMessage = "(no message: the comments below are the whole request)"

    public var message: String
    public var comments: String
    public var count: Int

    public init(message: String, comments: String, count: Int) {
        self.message = message
        self.comments = comments
        self.count = count
    }

    public init(message: String, comments: [ReviewComment], worktreePath: String?) {
        let noFiles: (String) -> [String]? = { _ in nil }
        let reader = worktreePath.map { ReviewPayload.worktreeReader(root: $0) } ?? noFiles
        self.init(
            message: message,
            comments: ReviewPayload.text(for: comments, currentLines: reader),
            count: comments.count
        )
    }

    public var values: [String: String] {
        [
            PromptRegistry.Review.message: message.isEmpty ? Self.noMessage : message,
            PromptRegistry.Review.comments: comments,
            PromptRegistry.Review.count: String(count),
        ]
    }

    public func render(template: String) -> PromptRender {
        PromptTemplate.render(template, values: values)
    }
}
