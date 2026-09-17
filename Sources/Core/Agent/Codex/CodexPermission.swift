import Foundation

public enum CodexPermission {
    public static func requestID(_ id: CodexRequestID, threadID: String) -> String {
        switch id {
        case .number(let value): "codex:\(threadID):\(value)"
        case .text(let value): "codex:\(threadID):\(value)"
        }
    }

    public static func ask(for request: CodexApprovalRequest, item: CodexItem?) -> PermissionAsk {
        let isQuestion = request.kind == .toolUserInput
        let toolName = isQuestion ? AgentQuestionnaire.toolName
            : item.map(CodexTranslation.toolName(for:)) ?? fallbackToolName(request.kind)
        let input = isQuestion ? CodexQuestionnaire.input(for: request)
            : item.map(CodexTranslation.input(for:)) ?? request.params
        let rule = rule(toolName: toolName, item: item, request: request)

        let ask = PermissionAsk(
            requestID: requestID(request.id, threadID: request.threadID),
            toolName: toolName,
            displayName: displayName(request.kind),
            toolUseID: request.itemID,
            input: input,
            summary: summary(for: request, item: item),
            reason: request.params["reason"]?.stringValue ?? "",
            reasonType: reasonType(request.kind),
            blockedPath: request.params["grantRoot"]?.stringValue,
            suggestions: rule.map { [PermissionSuggestion(
                type: "addRules",
                behavior: "allow",
                destination: PermissionDestination.session.rawValue,
                rules: [$0],
                raw: .object([:])
            )] } ?? [],
            suppressesAlwaysAllow: rule == nil,
            requiresUserInteraction: isQuestion,
            raw: Data()
        )
        return ask.with(raw: envelope(for: ask))
    }

    public static func envelope(for ask: PermissionAsk) -> Data {
        let json = JSONValue.object(omittingNil: [
            "type": .string("control_request"),
            "request_id": .string(ask.requestID),
            "agent_kind": .string(AgentKind.codex.rawValue),
            "request": .object(omittingNil: [
                "subtype": .string("can_use_tool"),
                "tool_name": .string(ask.toolName),
                "display_name": ask.displayName.isEmpty ? nil : .string(ask.displayName),
                "tool_use_id": .string(ask.toolUseID),
                "input": ask.input,
                "description": ask.summary.isEmpty ? nil : .string(ask.summary),
                "decision_reason": ask.reason.isEmpty ? nil : .string(ask.reason),
                "decision_reason_type": .string(ask.reasonType),
                "blocked_path": ask.blockedPath.map { .string($0) },
                "suppress_always_allow_rule": .bool(ask.suppressesAlwaysAllow),
                "requires_user_interaction": .bool(ask.requiresUserInteraction),
                "permission_suggestions": .array(ask.suggestions.map(suggestionJSON)),
            ]),
        ])
        return Data(json.compactJSON.utf8)
    }

    static func suggestionJSON(_ suggestion: PermissionSuggestion) -> JSONValue {
        .object([
            "type": .string(suggestion.type),
            "behavior": .string(suggestion.behavior),
            "destination": .string(suggestion.destination),
            "rules": .array(suggestion.rules.map { rule in
                .object(omittingNil: [
                    "toolName": .string(rule.toolName),
                    "ruleContent": rule.ruleContent.map { .string($0) },
                ])
            }),
        ])
    }

    static func rule(toolName: String, item: CodexItem?, request: CodexApprovalRequest) -> PermissionRule? {
        switch request.kind {
        case .commandExecution:
            let command = commandText(item: item, request: request)
            guard !command.isEmpty else { return nil }
            return PermissionRule(toolName: toolName, ruleContent: command)

        case .fileChange:
            guard case .fileChange(let change)? = item, let first = change.changes.first else {
                return nil
            }
            return PermissionRule(toolName: toolName, ruleContent: first.path)

        case .permissions, .mcpElicitation, .toolUserInput:
            return nil
        }
    }

    static func commandText(item: CodexItem?, request: CodexApprovalRequest) -> String {
        if case .commandExecution(let run)? = item, !run.command.isEmpty { return run.command }
        return request.command ?? ""
    }

    static func fallbackToolName(_ kind: CodexApprovalRequest.Kind) -> String {
        switch kind {
        case .commandExecution: "Shell"
        case .fileChange: "ApplyPatch"
        case .permissions: "Permissions"
        case .mcpElicitation: "McpElicitation"
        case .toolUserInput: "UserInput"
        }
    }

    static func displayName(_ kind: CodexApprovalRequest.Kind) -> String {
        switch kind {
        case .commandExecution: "Run a command"
        case .fileChange: "Change files"
        case .permissions: "Widen permissions"
        case .mcpElicitation: "Answer an MCP server"
        case .toolUserInput: "Answer a tool"
        }
    }

    static func reasonType(_ kind: CodexApprovalRequest.Kind) -> String {
        switch kind {
        case .commandExecution, .fileChange: "sandboxOverride"
        default: "other"
        }
    }

    static func summary(for request: CodexApprovalRequest, item: CodexItem?) -> String {
        switch request.kind {
        case .commandExecution:
            return commandText(item: item, request: request)
        case .fileChange:
            guard case .fileChange(let change)? = item else { return "Apply a patch" }
            let paths = change.changes.map(\.path)
            return paths.count == 1
                ? "\(change.changes[0].kind.label) \(paths[0])"
                : "\(paths.count) files"
        default:
            return displayName(request.kind)
        }
    }

    public static func decision(for decision: PermissionDecision) -> CodexApprovalDecision {
        switch decision {
        case .allow(.once): .accept
        case .allow(.session), .allow(.project): .acceptForSession
        case .answer: .accept
        case .approvePlan: .decline
        case .deny(_, let endsTurn): endsTurn ? .cancel : .decline
        }
    }
}

extension PermissionAsk {
    func with(raw: Data) -> PermissionAsk {
        var copy = self
        copy.raw = raw
        return copy
    }
}
