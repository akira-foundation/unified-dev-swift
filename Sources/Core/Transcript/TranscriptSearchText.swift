import Foundation

public enum TranscriptSearchText {
    public static let limit = 8_000

    private static let noiseKeys: Set<String> = [
        "id", "uuid", "type", "subtype", "role", "signature", "model", "version",
        "session_id", "sessionId", "tool_use_id", "toolUseId", "toolUseID",
        "parent_tool_use_id", "parentToolUseId", "call_id", "callId", "request_id", "requestId",
        "media_type", "mediaType", "data", "encoding", "permission_mode", "permissionMode",
        "leaf_uuid", "leafUuid", "message_id", "messageId", "parent_uuid", "parentUuid",
        "usage", "modelUsage", "model_usage", "diagnostics",
        "context_management", "contextManagement",
        "service_tier", "serviceTier", "inference_geo", "inferenceGeo", "speed", "provider",
        "canonical_model", "canonicalModel",
        "effort", "reasoning_effort", "reasoningEffort",
        "timestamp", "created_at", "createdAt", "updated_at", "updatedAt",
        "started_at", "startedAt", "completed_at", "completedAt", "date", "time",
        "stop_reason", "stopReason", "terminal_reason", "terminalReason",
        "finish_reason", "finishReason", "api_error_status", "apiErrorStatus",
        "fast_mode_state", "fastModeState",
        "fast_mode_disabled_reason", "fastModeDisabledReason",
        "sent",
    ]

    public static func isIndexed(_ kind: MessageKind) -> Bool {
        switch kind {
        case .user, .assistantText, .thinking, .toolUse, .toolResult, .error, .crew: true
        case .result, .system, .notice, .permissionAsk, .suggestion: false
        }
    }

    public static func indexable(kind: MessageKind, payload: Data) -> String? {
        guard isIndexed(kind) else { return nil }
        guard let json = JSONValue.parse(payload) else {
            return clean(String(decoding: payload, as: UTF8.self))
        }

        var pieces: [String] = []
        var seen: Set<String> = []
        collect(json, key: nil, into: &pieces, seen: &seen)
        return clean(pieces.joined(separator: " "))
    }

    private static func collect(
        _ value: JSONValue,
        key: String?,
        into pieces: inout [String],
        seen: inout Set<String>
    ) {
        guard pieces.reduce(0, { $0 + $1.count }) < limit else { return }

        if let key, noiseKeys.contains(key) { return }

        switch value {
        case .string(let text):
            guard key != nil else { return }
            guard text.contains(where: \.isLetter) else { return }
            guard seen.insert(text).inserted else { return }
            pieces.append(text)
        case .array(let items):
            for item in items { collect(item, key: key, into: &pieces, seen: &seen) }
        case .object(let object):
            for name in object.keys.sorted() {
                guard let child = object[name] else { continue }
                collect(child, key: name, into: &pieces, seen: &seen)
            }
        case .integer, .number, .bool, .null:
            return
        }
    }

    private static func clean(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.contains(where: \.isLetter) else { return nil }
        return trimmed.count <= limit ? trimmed : String(trimmed.prefix(limit))
    }
}
