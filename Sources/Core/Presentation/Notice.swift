import Foundation

public struct Notice: Identifiable, Equatable, Sendable {
    public enum Dismissal: Equatable, Sendable {
        case afterReading
        case untilDismissed
    }

    public let id = UUID()
    public var message: String
    public var dismissal: Dismissal
    public var tone: NoticeTone

    public init(message: String, tone: NoticeTone = .information, dismissal: Dismissal = .afterReading) {
        self.message = message
        self.tone = tone
        self.dismissal = dismissal
    }

    public static func sample(_ tone: NoticeTone) -> Notice {
        switch tone {
        case .information:
            Notice(message: "Notices appear here. Hold the pointer over one to keep it on screen.", tone: tone)
        case .warning:
            Notice(message: "Warnings appear here. They say what was not done, and why.", tone: tone)
        case .error:
            Notice(
                message: "Errors appear here. The reason follows, with names such as `main` set in monospace.",
                tone: tone
            )
        }
    }

    public var lifetime: Duration? {
        switch dismissal {
        case .afterReading: NoticeLifetime.reading(message)
        case .untilDismissed: nil
        }
    }

    public var text: NoticeText { NoticeText(message) }

    public var spoken: String { tone.spoken(text.plain) }
}

public enum NoticeLifetime {
    public static let noticing = Duration.milliseconds(1800)

    public static let perUnit = Duration.milliseconds(300)

    public static let shortest = Duration.seconds(4)

    public static let longest = Duration.seconds(12)

    public static func reading(_ message: String) -> Duration {
        let span = noticing + perUnit * units(in: message)
        return min(max(span, shortest), longest)
    }

    public static func units(in message: String) -> Int {
        let chunk = 12
        return message
            .split(whereSeparator: \.isWhitespace)
            .reduce(0) { total, token in
                let letters = token.filter { $0 != "`" }.count
                return total + 1 + max(0, letters - 1) / chunk
            }
    }
}

public struct NoticeRun: Equatable, Sendable {
    public var text: String
    public var isMachine: Bool

    public init(text: String, isMachine: Bool) {
        self.text = text
        self.isMachine = isMachine
    }
}

public struct NoticeText: Equatable, Sendable {
    public var fact: [NoticeRun]
    public var reason: [NoticeRun]

    public init(_ message: String) {
        let (first, rest) = Self.split(message)
        fact = Self.runs(in: first)
        reason = Self.runs(in: rest)
    }

    public var plain: String {
        let sentences = [fact, reason]
            .filter { !$0.isEmpty }
            .map { $0.map(\.text).joined() }
        return sentences.joined(separator: " ")
    }

    private static func split(_ message: String) -> (String, String) {
        var inMark = false
        var index = message.startIndex
        while index < message.endIndex {
            let character = message[index]
            if character == "`" { inMark.toggle() }
            let next = message.index(after: index)
            if character == ".", !inMark, next < message.endIndex, message[next] == " " {
                let head = String(message[message.startIndex...index])
                let tail = String(message[message.index(after: next)...])
                if !tail.isEmpty { return (head, tail) }
            }
            index = next
        }
        return (message, "")
    }

    private static func runs(in sentence: String) -> [NoticeRun] {
        guard !sentence.isEmpty else { return [] }
        let pieces = sentence.split(separator: "`", omittingEmptySubsequences: false)
        guard pieces.count % 2 == 1 else {
            return [NoticeRun(text: sentence.replacingOccurrences(of: "`", with: ""), isMachine: false)]
        }
        return pieces.enumerated().compactMap { position, piece in
            guard !piece.isEmpty else { return nil }
            return NoticeRun(text: String(piece), isMachine: position % 2 == 1)
        }
    }
}
