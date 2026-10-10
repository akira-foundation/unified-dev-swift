import Foundation

public enum IssueReport {
    public static let titleLimit = 80

    public static func title(from message: String, kind: Feedback.Kind) -> String {
        let prefix = kind.issuePrefix
        let firstLine = message
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }

        guard let firstLine else { return "\(prefix) from the app" }
        return "\(prefix): \(shortened(firstLine, to: titleLimit - prefix.count - 2))"
    }

    public static func body(
        message: String,
        kind: Feedback.Kind,
        environment: Feedback.Environment,
        logs: String?,
        imageCount: Int
    ) -> String {
        var parts = [Feedback.trimmed(message, to: Feedback.maxMessageCharacters)]

        if imageCount > 0 { parts.append(pictureSentence(imageCount)) }

        parts.append(table(environment))

        if let logs = logs?.trimmingCharacters(in: .whitespacesAndNewlines), !logs.isEmpty {
            parts.append("### Recent app logs\n\n```\n\(AppLogExcerpt.capped(logs))\n```")
        }

        return parts.joined(separator: "\n\n") + "\n"
    }

    public static func labels(for kind: Feedback.Kind) -> [String] {
        switch kind {
        case .report: ["bug"]
        case .prompt: ["enhancement"]
        }
    }

    public static func cut(_ body: String) -> String {
        let fences = body.components(separatedBy: fence).count - 1
        let closed = fences.isMultiple(of: 2) ? body : "\(body)\n\(fence)"
        return closed + AppRepository.cutNotice
    }

    static let fence = "```"

    private static func pictureSentence(_ count: Int) -> String {
        "\(Counted.of(count, "screenshot")) \(Counted.word(count, "belongs", plural: "belong")) "
            + "with this report."
    }

    private static func table(_ environment: Feedback.Environment) -> String {
        let rows = environment.fields.map { "| \($0.name) | \(reading(of: $0.value)) |" }
        return (["| Field | Value |", "| --- | --- |"] + rows).joined(separator: "\n")
    }

    private static func reading(of value: Feedback.FieldValue) -> String {
        switch value {
        case .text(let text): text
        case .number(let number): Feedback.number(number)
        case .boolean(let flag): flag ? "yes" : "no"
        case .list(let values): values.joined(separator: ", ")
        }
    }

    private static func shortened(_ text: String, to limit: Int) -> String {
        guard text.count > limit, limit > 1 else { return text }
        let head = String(text.prefix(limit - 1))
        guard let space = head.lastIndex(of: " ") else { return head + "…" }
        let cut = head[head.startIndex..<space].trimmingCharacters(in: .whitespaces)
        return cut.isEmpty ? head + "…" : cut + "…"
    }
}

extension Feedback.Kind {
    var issuePrefix: String {
        switch self {
        case .report: "Feedback"
        case .prompt: "Prompt suggestion"
        }
    }
}
