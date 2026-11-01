import Foundation

public enum TaskStopRequest {
    public static func encode(taskID: SubagentID, requestID: String = UUID().uuidString) throws -> String {
        let envelope = JSONValue.object([
            "type": .string("control_request"),
            "request_id": .string(requestID),
            "request": .object([
                "subtype": .string("stop_task"),
                "task_id": .string(taskID.rawValue),
            ]),
        ])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return String(decoding: try encoder.encode(envelope), as: UTF8.self)
    }
}
