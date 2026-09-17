import Foundation

public struct MCPRequest: Sendable, Hashable {
    public let id: JSONValue?
    public let method: String
    public let params: JSONValue?

    public init(id: JSONValue?, method: String, params: JSONValue? = nil) {
        self.id = id
        self.method = method
        self.params = params
    }

    public var isNotification: Bool { id == nil || id == .null }

    public var replyID: JSONValue? { isNotification ? nil : id }

    public static func decode(_ line: String) -> MCPRequest? {
        guard let data = line.data(using: .utf8),
              let value = try? JSONDecoder().decode(JSONValue.self, from: data),
              case .object(let fields) = value,
              case .string(let method)? = fields["method"]
        else { return nil }
        return MCPRequest(id: fields["id"], method: method, params: fields["params"])
    }

    public func param(_ name: String) -> JSONValue? {
        guard case .object(let fields)? = params else { return nil }
        return fields[name]
    }

    public func stringParam(_ name: String) -> String? {
        guard case .string(let value)? = param(name) else { return nil }
        return value
    }
}

public struct MCPResponse: Sendable, Hashable {
    public let id: JSONValue
    public let payload: JSONValue

    private init(id: JSONValue, payload: JSONValue) {
        self.id = id
        self.payload = payload
    }

    public static func result(id: JSONValue, _ value: JSONValue) -> MCPResponse {
        MCPResponse(id: id, payload: .object(["result": value]))
    }

    public static func failure(id: JSONValue, code: Int, message: String) -> MCPResponse {
        MCPResponse(id: id, payload: .object([
            "error": .object(["code": .integer(code), "message": .string(message)]),
        ]))
    }

    public func line() -> String {
        var fields: [String: JSONValue] = ["jsonrpc": .string("2.0"), "id": id]
        if case .object(let payload) = payload {
            for (key, value) in payload { fields[key] = value }
        }
        let data = (try? JSONEncoder().encode(JSONValue.object(fields)))
            ?? Data(#"{"jsonrpc":"2.0","id":null,"error":{"code":-32603,"message":"unencodable"}}"#.utf8)
        return String(decoding: data, as: UTF8.self)
    }
}

public enum MCPErrorCode {
    public static let invalidRequest = -32_600
    public static let methodNotFound = -32_601
    public static let invalidParams = -32_602
    public static let internalError = -32_603
}
