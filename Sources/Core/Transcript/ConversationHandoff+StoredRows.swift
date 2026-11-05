import Foundation

extension ConversationHandoff {
    static var storedKindList: String {
        storedKinds.map { "'\($0.rawValue)'" }.joined(separator: ", ")
    }

    private static let text = "CAST(payload AS TEXT)"
    private static let block = "'$.message.content[0]"

    private static func field(_ path: String) -> String {
        "json_extract(\(text), \(block)\(path)')"
    }

    private static let boundedResult = """
        json_remove(json_set(\(text), \(block).content', CASE json_type(\(text), \(block).content')
            WHEN 'text' THEN substr(\(field(".content")), 1, \(boundedResultCharacters))
            ELSE substr(COALESCE(\(field(".content[0].text")), ''), 1, \(boundedResultCharacters))
        END), '$.tool_use_result')
        """

    private static let boundedCall: String = {
        let keys = targetKeys.map {
            "'\($0)', substr(\(field(".input.\($0)")), 1, \(boundedTargetCharacters))"
        }
        return "json_set(\(text), \(block).input', json_object(\(keys.joined(separator: ", "))))"
    }()

    private static func bounded(_ expression: String) -> String {
        "CASE WHEN json_valid(\(text)) THEN CAST(\(expression) AS BLOB) ELSE CAST('{}' AS BLOB) END"
    }

    static let boundedPayload = """
        CASE
            WHEN length(payload) <= \(oversizedRowBytes) THEN payload
            WHEN kind = '\(MessageKind.toolResult.rawValue)' THEN \(bounded(boundedResult))
            WHEN kind = '\(MessageKind.toolUse.rawValue)' THEN \(bounded(boundedCall))
            ELSE payload
        END
        """
}
