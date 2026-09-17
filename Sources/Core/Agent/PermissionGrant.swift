import Foundation

public struct PermissionGrant: Identifiable, Sendable, Hashable, Codable {
    public var id: PermissionGrantID
    public var repoID: RepoID
    public var toolName: String
    public var ruleContent: String?
    public var grantedAt: Date
    public var lastUsedAt: Date?
    public var useCount: Int
    public var grantedFor: String

    public init(
        id: PermissionGrantID = .new(),
        repoID: RepoID,
        toolName: String,
        ruleContent: String? = nil,
        grantedAt: Date = Date(),
        lastUsedAt: Date? = nil,
        useCount: Int = 0,
        grantedFor: String = ""
    ) {
        self.id = id
        self.repoID = repoID
        self.toolName = toolName
        self.ruleContent = ruleContent
        self.grantedAt = grantedAt
        self.lastUsedAt = lastUsedAt
        self.useCount = useCount
        self.grantedFor = grantedFor
    }

    public var rule: PermissionRule {
        PermissionRule(toolName: toolName, ruleContent: ruleContent)
    }

    public var displayText: String { rule.displayText }

    public static func granting(_ rule: PermissionRule, repoID: RepoID, for subject: String = "") -> PermissionGrant {
        PermissionGrant(
            repoID: repoID,
            toolName: rule.toolName,
            ruleContent: rule.ruleContent,
            grantedFor: subject
        )
    }

    public static func all(
        granting decision: PermissionDecision, from ask: PermissionAsk, repoID: RepoID
    ) -> [PermissionGrant] {
        guard case .allow(.project) = decision else { return [] }

        return ask.rules.map { granting($0, repoID: repoID, for: ask.subject) }
    }
}

public enum PermissionGrantIndex {
    public static func match(ask: PermissionAsk, grants: [PermissionGrant]) -> [PermissionGrant]? {
        guard ask.canWiden, let suggestion = ask.allowSuggestion else { return nil }

        var matched: [PermissionGrant] = []
        for rule in suggestion.rules {
            guard let grant = grants.first(where: { $0.rule == rule }) else { return nil }
            matched.append(grant)
        }
        return matched.isEmpty ? nil : matched
    }

    public static func note(for grants: [PermissionGrant]) -> String {
        let rules = grants.map(\.displayText).joined(separator: ", ")
        return "Allowed by \(rules), which you approved for this project."
    }
}

public struct PendingPermissionAsk: Identifiable, Sendable, Hashable {
    public var requestID: String
    public var sessionID: SessionID
    public var ask: PermissionAsk
    public var askedAt: Date

    public var id: String { requestID }

    public init(requestID: String, sessionID: SessionID, ask: PermissionAsk, askedAt: Date) {
        self.requestID = requestID
        self.sessionID = sessionID
        self.ask = ask
        self.askedAt = askedAt
    }
}

public enum PermissionAskOutcome {
    public static let quit = "quit"
    public static let stopped = "stopped"
    public static let abandoned = "abandoned"
    public static let auto = "allow-project-auto"
    public static let resolved = "resolved-by-agent"

    public static func wentUnanswered(_ decision: String) -> Bool {
        [quit, stopped, abandoned, resolved].contains(decision)
    }

    public static func summary(_ decision: String) -> String {
        switch decision {
        case quit: "Unified Dev closed this session before the question was answered."
        case stopped: "The turn was stopped before this was answered."
        case abandoned: "Unified Dev was not running when this was asked, so it went unanswered."
        case resolved: "The agent closed this question before it was answered."
        default: ""
        }
    }

    public static func advice(_ decision: String) -> String {
        wentUnanswered(decision)
            ? "Nothing was lost. The worktree still holds whatever the agent had changed, and the turn can be sent again."
            : ""
    }
}

public struct PermissionResolution: Sendable, Hashable {
    public var requestID: String
    public var toolUseID: String
    public var decision: String
    public var note: String

    public init(requestID: String, toolUseID: String = "", decision: String, note: String = "") {
        self.requestID = requestID
        self.toolUseID = toolUseID
        self.decision = decision
        self.note = note
    }
}
