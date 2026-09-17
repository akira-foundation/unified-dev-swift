import Foundation

public enum ToolRefusal: Sendable, Hashable {
    public static let protocolKinds = [
        "user-rejected",
        "permission-rule",
        "automode-blocked",
        "automode-unavailable",
        "automode-parsing-error",
        "interrupted",
        "cancelled",
    ]

    case denied
    case stopped
    case notRun

    public var label: String {
        switch self {
        case .denied: "denied"
        case .stopped: "stopped"
        case .notRun: "not run"
        }
    }

    public var summary: String {
        switch self {
        case .denied: "The agent asked to run this and permission was not granted."
        case .stopped: "The turn was stopped before this call ran."
        case .notRun: "This call did not run."
        }
    }

    public var remedy: String? {
        switch self {
        case .denied: "Pick a permission mode under the composer that allows it, then ask again."
        case .stopped, .notRun: nil
        }
    }

    public init?(protocolKind: String?) {
        switch protocolKind {
        case "user-rejected", "permission-rule", "automode-blocked": self = .denied
        case "interrupted", "cancelled", "canceled": self = .stopped
        case "automode-unavailable", "automode-parsing-error": self = .notRun
        case .some(let kind) where !kind.isEmpty: self = .notRun
        default: return nil
        }
    }
}

public struct ToolResultSummary: Sendable, Hashable {
    public var isError: Bool
    public var refusal: ToolRefusal?
    public var reason: String

    public init(isError: Bool = false, refusal: ToolRefusal? = nil, reason: String = "") {
        self.isError = isError
        self.refusal = refusal
        self.reason = reason
    }

    public static func decode(_ payload: Data) -> ToolResultSummary {
        guard let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let message = object["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]]
        else {
            return ToolResultSummary()
        }

        let results = content.filter { (($0["type"] as? String) ?? "tool_result") == "tool_result" }
        guard results.contains(where: { ($0["is_error"] as? Bool) == true }) else {
            return ToolResultSummary()
        }

        let meta = object["tool_result_meta"] as? [[String: Any]] ?? []
        let ids = Set(results.compactMap { $0["tool_use_id"] as? String })
        let kind = meta
            .first { ids.contains(($0["id"] as? String) ?? "") }
            .flatMap { $0["non_execution_kind"] as? String }

        guard let refusal = ToolRefusal(protocolKind: kind) else {
            return ToolResultSummary(isError: true)
        }

        return ToolResultSummary(
            isError: true,
            refusal: refusal,
            reason: firstLine(of: results.first { ($0["is_error"] as? Bool) == true })
        )
    }

    private static func firstLine(of block: [String: Any]?) -> String {
        guard let block else { return "" }
        let text: String
        if let string = block["content"] as? String {
            text = string
        } else if let blocks = block["content"] as? [[String: Any]] {
            text = blocks.compactMap { $0["text"] as? String }.joined(separator: "\n")
        } else {
            return ""
        }
        return text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .first
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
    }
}
