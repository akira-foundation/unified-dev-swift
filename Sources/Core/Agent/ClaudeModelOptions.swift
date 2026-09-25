import Foundation

public enum ClaudeModelOptions {
    public static let key = "additionalModelOptionsCache"

    public static func decode(_ accountJSON: Data?) -> [AgentModel] {
        guard let accountJSON, let root = JSONValue.parse(accountJSON) else { return [] }
        return (root[key]?.arrayValue ?? []).compactMap(model)
    }

    static func model(_ json: JSONValue) -> AgentModel? {
        guard let id = json["value"]?.stringValue,
              !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let described = json["description"]?.stringValue ?? ""
        let unavailable = json["disabled"]?.boolValue ?? false

        return AgentModel(
            id: id,
            displayName: name(id, label: json["label"]?.stringValue ?? ""),
            unavailable: unavailable ? reason(described) : nil
        )
    }

    static func name(_ id: String, label: String) -> String {
        guard !ClaudeModelRank.recognises(id) else { return ModelLabel.readable(id) }
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ModelLabel.readable(id) }
        return withoutDisabledMark(trimmed)
    }

    static func withoutDisabledMark(_ label: String) -> String {
        let mark = "(disabled)"
        guard label.hasSuffix(mark) else { return label }
        return String(label.dropLast(mark.count)).trimmingCharacters(in: .whitespaces)
    }

    static func reason(_ described: String) -> String {
        let trimmed = described.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Not available on this account." : trimmed
    }
}
