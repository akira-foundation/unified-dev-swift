import Foundation
@testable import Core

enum QuotedWorkspaceAnswer {
    static func body(_ text: String) -> String? {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard let start = lines.firstIndex(of: Substring(BridgeUntrustedText.opening)),
              let end = lines.lastIndex(of: Substring(BridgeUntrustedText.closing)),
              start < end else { return nil }
        return lines[(start + 1)..<end].joined(separator: "\n")
    }

    static func json(_ text: String) -> JSONValue? {
        body(text).flatMap(JSONValue.parse)
    }
}
