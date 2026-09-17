import Foundation

public enum SubagentSignal: Sendable, Hashable {
    case started(SubagentStart)
    case progressed(SubagentProgress)
    case patched(SubagentPatch)
    case reported(SubagentReport)

    public static func decode(_ json: JSONValue, raw: Data = Data()) -> SubagentSignal? {
        switch json["type"]?.stringValue {
        case "tool_progress":
            guard let parent = json["parent_tool_use_id"]?.stringValue else { return nil }
            return .progressed(SubagentProgress(
                parentToolUseID: parent,
                type: json["subagent_type"]?.stringValue ?? "",
                elapsedSeconds: json["elapsed_time_seconds"]?.intValue ?? 0,
                retry: AgentRetry.subagentRetry(json, raw: raw)
            ))

        case "system":
            switch json["subtype"]?.stringValue {
            case "task_started":
                guard let id = json["task_id"]?.stringValue, !id.isEmpty else { return nil }
                return .started(SubagentStart(
                    id: SubagentID(id),
                    toolUseID: json["tool_use_id"]?.stringValue ?? "",
                    description: json["description"]?.stringValue ?? "",
                    type: json["subagent_type"]?.stringValue ?? "",
                    isBackgrounded: json["is_backgrounded"]?.boolValue ?? false,
                    spawnDepth: json["spawn_depth"]?.intValue ?? 1,
                    taskType: json["task_type"]?.stringValue ?? "",
                    prompt: json["prompt"]?.stringValue ?? ""
                ))

            case "task_updated":
                guard let id = json["task_id"]?.stringValue, !id.isEmpty else { return nil }
                let patch = json["patch"]
                return .patched(SubagentPatch(
                    id: SubagentID(id),
                    status: patch?["status"]?.stringValue,
                    error: patch?["error"]?.stringValue
                ))

            case "task_notification":
                guard let id = json["task_id"]?.stringValue, !id.isEmpty else { return nil }
                return .reported(SubagentReport(
                    id: SubagentID(id),
                    status: json["status"]?.stringValue ?? "",
                    summary: json["summary"]?.stringValue ?? "",
                    outputFile: json["output_file"]?.stringValue,
                    raw: raw
                ))

            default:
                return nil
            }

        default:
            return nil
        }
    }

    public var subagentID: SubagentID? {
        switch self {
        case .started(let start): start.id
        case .patched(let patch): patch.id
        case .reported(let report): report.id
        case .progressed: nil
        }
    }
}

public struct SubagentStart: Sendable, Hashable {
    public let id: SubagentID
    public let toolUseID: String
    public let description: String
    public let type: String
    public let isBackgrounded: Bool
    public let spawnDepth: Int
    public let taskType: String
    public let prompt: String
    public let resumesExisting: Bool

    public init(
        id: SubagentID,
        toolUseID: String = "",
        description: String = "",
        type: String = "",
        isBackgrounded: Bool = false,
        spawnDepth: Int = 1,
        taskType: String = "",
        prompt: String = "",
        resumesExisting: Bool = false
    ) {
        self.id = id
        self.toolUseID = toolUseID
        self.description = description
        self.type = type
        self.isBackgrounded = isBackgrounded
        self.spawnDepth = spawnDepth
        self.taskType = taskType
        self.prompt = prompt
        self.resumesExisting = resumesExisting
    }
}

public struct SubagentProgress: Sendable, Hashable {
    public let parentToolUseID: String
    public let type: String
    public let elapsedSeconds: Int
    public let retry: AgentRetry?

    public init(
        parentToolUseID: String,
        type: String = "",
        elapsedSeconds: Int = 0,
        retry: AgentRetry? = nil
    ) {
        self.parentToolUseID = parentToolUseID
        self.type = type
        self.elapsedSeconds = elapsedSeconds
        self.retry = retry
    }
}

public struct SubagentPatch: Sendable, Hashable {
    public let id: SubagentID
    public let status: String?
    public let error: String?

    public init(id: SubagentID, status: String? = nil, error: String? = nil) {
        self.id = id
        self.status = status
        self.error = error
    }
}

public struct SubagentReport: Sendable, Hashable {
    public let id: SubagentID
    public let status: String
    public let summary: String
    public let outputFile: String?
    public let raw: Data

    public init(
        id: SubagentID, status: String, summary: String = "", outputFile: String? = nil, raw: Data = Data()
    ) {
        self.id = id
        self.status = status
        self.summary = summary
        self.outputFile = outputFile
        self.raw = raw
    }
}
