import Foundation

public struct TranscriptMatch: Sendable, Hashable, Identifiable {
    public var id: Int64 { messageID }
    public var messageID: Int64
    public var workspaceID: WorkspaceID
    public var sessionID: SessionID
    public var sessionTitle: String
    public var seq: Int
    public var kind: MessageKind
    public var createdAt: Date
    public var snippet: TranscriptSnippet
    public var score: Double

    public init(
        messageID: Int64,
        workspaceID: WorkspaceID,
        sessionID: SessionID,
        sessionTitle: String,
        seq: Int,
        kind: MessageKind,
        createdAt: Date,
        snippet: TranscriptSnippet,
        score: Double
    ) {
        self.messageID = messageID
        self.workspaceID = workspaceID
        self.sessionID = sessionID
        self.sessionTitle = sessionTitle
        self.seq = seq
        self.kind = kind
        self.createdAt = createdAt
        self.snippet = snippet
        self.score = score
    }
}

public struct TranscriptWorkspaceMatches: Sendable, Hashable, Identifiable {
    public var id: WorkspaceID { workspaceID }
    public var workspaceID: WorkspaceID
    public var matches: [TranscriptMatch]
    public var total: Int

    public var best: TranscriptMatch? { matches.first }

    public init(workspaceID: WorkspaceID, matches: [TranscriptMatch], total: Int) {
        self.workspaceID = workspaceID
        self.matches = matches
        self.total = total
    }
}

public struct TranscriptSearchTarget: Sendable, Hashable {
    public var workspaceID: WorkspaceID
    public var sessionID: SessionID
    public var seq: Int

    public init(workspaceID: WorkspaceID, sessionID: SessionID, seq: Int) {
        self.workspaceID = workspaceID
        self.sessionID = sessionID
        self.seq = seq
    }
}

public struct TranscriptSnippet: Sendable, Hashable {
    public struct Segment: Sendable, Hashable {
        public var text: String
        public var isMatch: Bool

        public init(text: String, isMatch: Bool) {
            self.text = text
            self.isMatch = isMatch
        }
    }

    public var segments: [Segment]

    public init(segments: [Segment]) {
        self.segments = segments
    }

    public var text: String { segments.map(\.text).joined() }
    public var isEmpty: Bool { segments.allSatisfy { $0.text.isEmpty } }
}

public enum TranscriptSearch {
    public static let minimumQueryLength = 2

    public static let matchesPerWorkspace = 3

    public static let candidateLimit = 400

    public static let openMark = "\u{02}"
    public static let closeMark = "\u{03}"

    public static func matchExpression(for query: String) -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minimumQueryLength else { return nil }

        let tokens = tokens(in: trimmed)
        guard !tokens.isEmpty else { return nil }

        let endsMidWord = !(query.last?.isWhitespace ?? true) && !(query.hasSuffix("\""))
        return tokens.enumerated()
            .map { index, token in
                let quoted = "\"" + token.text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
                let isLast = index == tokens.count - 1
                return isLast && endsMidWord && !token.wasQuoted ? quoted + "*" : quoted
            }
            .joined(separator: " AND ")
    }

    private struct Token {
        var text: String
        var wasQuoted: Bool
    }

    private static func tokens(in query: String) -> [Token] {
        var tokens: [Token] = []
        var current = ""
        var inQuotes = false

        func flush(wasQuoted: Bool) {
            let text = current.trimmingCharacters(in: .whitespacesAndNewlines)
            current = ""
            guard text.contains(where: { $0.isLetter || $0.isNumber }) else { return }
            tokens.append(Token(text: text, wasQuoted: wasQuoted))
        }

        for character in query {
            if character == "\"" {
                flush(wasQuoted: inQuotes)
                inQuotes.toggle()
            } else if character.isWhitespace, !inQuotes {
                flush(wasQuoted: false)
            } else {
                current.append(character)
            }
        }
        flush(wasQuoted: inQuotes)
        return tokens
    }

    public static func snippet(from marked: String) -> TranscriptSnippet {
        var segments: [TranscriptSnippet.Segment] = []
        var current = ""
        var isMatch = false

        func flush() {
            guard !current.isEmpty else { return }
            if var last = segments.last, last.isMatch == isMatch {
                last.text += current
                segments[segments.count - 1] = last
            } else {
                segments.append(TranscriptSnippet.Segment(text: current, isMatch: isMatch))
            }
            current = ""
        }

        for character in marked {
            if String(character) == openMark {
                flush()
                isMatch = true
            } else if String(character) == closeMark {
                flush()
                isMatch = false
            } else {
                current.append(character)
            }
        }
        flush()

        return TranscriptSnippet(segments: segments)
    }

    public static func group(
        _ matches: [TranscriptMatch],
        totals: [WorkspaceID: Int] = [:],
        perWorkspace: Int = matchesPerWorkspace
    ) -> [TranscriptWorkspaceMatches] {
        var order: [WorkspaceID] = []
        var byWorkspace: [WorkspaceID: [TranscriptMatch]] = [:]

        for match in matches {
            if byWorkspace[match.workspaceID] == nil { order.append(match.workspaceID) }
            byWorkspace[match.workspaceID, default: []].append(match)
        }

        return order.map { workspaceID in
            let all = byWorkspace[workspaceID] ?? []
            return TranscriptWorkspaceMatches(
                workspaceID: workspaceID,
                matches: Array(all.prefix(perWorkspace)),
                total: max(totals[workspaceID] ?? all.count, all.count)
            )
        }
    }

    public static func label(for kind: MessageKind) -> String {
        switch kind {
        case .user: "You"
        case .assistantText: "Agent"
        case .thinking: "Thinking"
        case .toolUse: "Tool call"
        case .toolResult: "Tool output"
        case .error: "Error"
        case .crew: "Message"
        case .result, .system, .notice, .permissionAsk: "Transcript"
        }
    }
}
