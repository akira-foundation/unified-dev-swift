import Foundation

public enum CheckFailureHandoff {
    public struct LogTarget: Sendable, Equatable {
        public var runID: String
        public var jobID: String?

        public init(runID: String, jobID: String? = nil) {
            self.runID = runID
            self.jobID = jobID
        }
    }

    public static func logTarget(detailsURL: String?) -> LogTarget? {
        guard let detailsURL, let url = URL(string: detailsURL),
              let host = url.host?.lowercased(), host == "github.com" || host.hasSuffix(".github.com")
        else { return nil }

        let parts = url.path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard let runs = parts.firstIndex(of: "runs"), runs > 0, parts[runs - 1] == "actions",
              runs + 1 < parts.count
        else { return nil }

        let runID = parts[runs + 1]
        guard runID.allSatisfy(\.isNumber), !runID.isEmpty else { return nil }

        var jobID: String?
        if let job = parts.firstIndex(of: "job"), job + 1 < parts.count {
            let candidate = parts[job + 1]
            if !candidate.isEmpty, candidate.allSatisfy(\.isNumber) { jobID = candidate }
        }
        return LogTarget(runID: runID, jobID: jobID)
    }

    public static let headLines = 40

    public static let tailLines = 160

    public static let maxCharacters = 24_000

    public struct Excerpt: Sendable, Equatable {
        public var text: String
        public var totalLines: Int
        public var droppedLines: Int

        public var isTruncated: Bool { droppedLines > 0 }

        public init(text: String, totalLines: Int, droppedLines: Int) {
            self.text = text
            self.totalLines = totalLines
            self.droppedLines = droppedLines
        }
    }

    public static func excerpt(
        _ log: String,
        headLines: Int = headLines,
        tailLines: Int = tailLines,
        maxCharacters: Int = maxCharacters
    ) -> Excerpt {
        let lines = clean(log)
        let total = lines.count

        guard total > headLines + tailLines else {
            return capped(lines.joined(separator: "\n"), totalLines: total, dropped: 0, limit: maxCharacters)
        }

        let dropped = total - headLines - tailLines
        let kept = lines.prefix(headLines)
            + ["", "[\(dropped) lines of this log are not shown]", ""]
            + lines.suffix(tailLines)
        return capped(
            kept.joined(separator: "\n"), totalLines: total, dropped: dropped, limit: maxCharacters
        )
    }

    private static func capped(
        _ text: String, totalLines: Int, dropped: Int, limit: Int
    ) -> Excerpt {
        guard text.count > limit else {
            return Excerpt(text: text, totalLines: totalLines, droppedLines: dropped)
        }
        let cut = String(text.prefix(limit)) + "\n[the rest of this log is not shown]"
        return Excerpt(text: cut, totalLines: totalLines, droppedLines: dropped)
    }

    public static func clean(_ log: String) -> [String] {
        log.split(separator: "\n", omittingEmptySubsequences: false).map { raw in
            var line = String(raw)
            if line.hasPrefix("\u{FEFF}") { line.removeFirst() }
            if let lastTab = line.range(of: "\t", options: .backwards),
               line.filter({ $0 == "\t" }).count >= 2 {
                line = String(line[lastTab.upperBound...])
            }
            line = stripTimestamp(line)
            return stripAnsi(line).trimmingCharacters(in: .whitespaces)
        }
    }

    private static func stripTimestamp(_ line: String) -> String {
        guard let space = line.firstIndex(of: " ") else { return line }
        let head = line[line.startIndex..<space]
        guard head.count >= 20, head.hasSuffix("Z"), head.contains("T"),
              head.prefix(4).allSatisfy(\.isNumber)
        else { return line }
        return String(line[line.index(after: space)...])
    }

    private static func stripAnsi(_ line: String) -> String {
        guard line.contains("\u{1B}") else { return line }
        var out = ""
        var scanning = false
        for character in line {
            if scanning {
                if character.isLetter { scanning = false }
                continue
            }
            if character == "\u{1B}" { scanning = true; continue }
            out.append(character)
        }
        return out
    }

    public static func logFilename(for name: String, at date: Date = .now, timeZone: TimeZone = .current) -> String {
        var safe = name
        for bad in ["/", ":", "`"] { safe = safe.replacingOccurrences(of: bad, with: "-") }
        safe = safe.trimmingCharacters(in: .whitespacesAndNewlines)
        while safe.hasPrefix(".") { safe.removeFirst() }
        let label = safe.isEmpty ? "check" : safe
        return "\(label) \(PastedAttachment.timestamp(date, in: timeZone)).log"
    }

    public static func sentence(
        name: String,
        workflow: String? = nil,
        state: CheckState,
        detailsURL: String? = nil,
        logPath: String? = nil,
        excerpt: Excerpt? = nil
    ) -> String {
        let place = workflow.map { $0.isEmpty || $0 == name ? "" : " in \($0)" } ?? ""
        var sentence = "The GitHub check \"\(name)\"\(place) \(state.description.lowercased())."

        if let logPath {
            let cut = excerpt?.isTruncated == true
                ? " Only part of the log is there, taken from both ends of it."
                : ""
            sentence += " Its log is in \(AttachmentDraft.token(for: logPath)).\(cut)"
        } else {
            sentence += " Unified Dev could not fetch its log."
        }

        if let detailsURL, !detailsURL.isEmpty { sentence += " The run is at \(detailsURL)." }
        return sentence
    }
}
