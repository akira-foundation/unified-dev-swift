import Foundation

public enum ModelRefusal {
    public static let marker = "[claude-code:unrecognized_model]"

    public static func model(inStderr text: String) -> String? {
        for line in AgentExit.stripEscapes(text).split(whereSeparator: \.isNewline) {
            guard line.hasPrefix(marker) else { continue }
            let rest = line.dropFirst(marker.count)
            return JSONValue.parse(Data(rest.utf8))?["model"]?.stringValue ?? ""
        }
        return nil
    }
}
