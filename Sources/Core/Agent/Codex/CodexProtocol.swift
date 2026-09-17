import Foundation

public enum CodexRequestID: Sendable, Hashable, Codable {
    case number(Int)
    case text(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self) {
            self = .number(value)
        } else {
            self = .text(try container.decode(String.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .number(let value): try container.encode(value)
        case .text(let value): try container.encode(value)
        }
    }

    var jsonLiteral: String {
        switch self {
        case .number(let value): String(value)
        case .text(let value): JSONValue.string(value).compactJSON
        }
    }

    init?(_ json: JSONValue?) {
        switch json {
        case .integer(let value): self = .number(value)
        case .string(let value): self = .text(value)
        default: return nil
        }
    }
}

public struct CodexRPCError: Sendable, Hashable, Error {
    public let code: Int
    public let message: String
    public let data: JSONValue?

    public init(code: Int, message: String, data: JSONValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

public enum CodexClientError: Sendable, Error, Equatable {
    case connectionClosed(String)
    case unexpectedResult(method: String)
    case notInitialized
    case timedOut(method: String, seconds: Int)
}

extension CodexClientError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .connectionClosed(let reason):
            reason.isEmpty
                ? "The connection to Codex closed"
                : "The connection to Codex closed: \(reason)"
        case .unexpectedResult:
            "Codex returned a response Unified Dev could not read"
        case .notInitialized:
            "Unified Dev could not connect to Codex"
        case .timedOut(let method, _):
            switch method {
            case "thread/resume":
                "Codex did not respond while reopening this conversation"
            case "thread/start":
                "Codex did not respond while starting this conversation"
            case "turn/start":
                "Codex did not accept the message in time"
            default:
                "Codex did not respond in time"
            }
        }
    }
}

public struct CodexServerRequest: Sendable, Hashable {
    public let id: CodexRequestID
    public let method: String
    public let params: JSONValue
    public let raw: Data

    public init(id: CodexRequestID, method: String, params: JSONValue, raw: Data = Data()) {
        self.id = id
        self.method = method
        self.params = params
        self.raw = raw
    }
}

public struct CodexServerNotification: Sendable, Hashable {
    public let method: String
    public let params: JSONValue
    public let raw: Data

    public init(method: String, params: JSONValue, raw: Data = Data()) {
        self.method = method
        self.params = params
        self.raw = raw
    }
}

public enum CodexFrame: Sendable, Hashable {
    case response(id: CodexRequestID, result: JSONValue, raw: Data)
    case failure(id: CodexRequestID, error: CodexRPCError, raw: Data)
    case request(CodexServerRequest)
    case notification(CodexServerNotification)
    case malformed(Data)

    public static func decode(line: String) -> CodexFrame? {
        guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let raw = Data(line.utf8)
        guard let json = JSONValue.parse(raw), case .object = json else { return .malformed(raw) }

        let id = CodexRequestID(json["id"])
        let params = json["params"] ?? .object([:])

        if let method = json["method"]?.stringValue {
            if let id {
                return .request(CodexServerRequest(id: id, method: method, params: params, raw: raw))
            }
            return .notification(CodexServerNotification(method: method, params: params, raw: raw))
        }

        guard let id else { return .malformed(raw) }

        if let error = json["error"] {
            return .failure(
                id: id,
                error: CodexRPCError(
                    code: error["code"]?.intValue ?? 0,
                    message: error["message"]?.stringValue ?? "",
                    data: error["data"]
                ),
                raw: raw
            )
        }

        guard case .object(let object) = json, object.keys.contains("result") else {
            return .malformed(raw)
        }
        return .response(id: id, result: object["result"] ?? .null, raw: raw)
    }
}

public enum CodexOutgoing {
    static let version = "2.0"

    public static func request(id: CodexRequestID, method: String, params: JSONValue?) -> String {
        var members = ["\"jsonrpc\":\"\(version)\"", "\"id\":\(id.jsonLiteral)"]
        members.append("\"method\":\(JSONValue.string(method).compactJSON)")
        if let params { members.append("\"params\":\(params.compactJSON)") }
        return "{" + members.joined(separator: ",") + "}"
    }

    public static func notification(method: String, params: JSONValue?) -> String {
        var members = ["\"jsonrpc\":\"\(version)\""]
        members.append("\"method\":\(JSONValue.string(method).compactJSON)")
        if let params { members.append("\"params\":\(params.compactJSON)") }
        return "{" + members.joined(separator: ",") + "}"
    }

    public static func response(id: CodexRequestID, result: JSONValue) -> String {
        "{\"jsonrpc\":\"\(version)\",\"id\":\(id.jsonLiteral),\"result\":\(result.compactJSON)}"
    }

    public static func failure(id: CodexRequestID, code: Int, message: String) -> String {
        let error = JSONValue.object([
            "code": .integer(code),
            "message": .string(message),
        ])
        return "{\"jsonrpc\":\"\(version)\",\"id\":\(id.jsonLiteral),\"error\":\(error.compactJSON)}"
    }
}

extension JSONValue {
    public var compactJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        guard let data = try? encoder.encode(self) else { return "null" }
        return String(decoding: data, as: UTF8.self)
    }

    public static func object(omittingNil entries: [String: JSONValue?]) -> JSONValue {
        .object(entries.compactMapValues { $0 })
    }
}
