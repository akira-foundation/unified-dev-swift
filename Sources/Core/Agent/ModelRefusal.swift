import Foundation

public enum ModelRefusal {
    public static let marker = "[claude-code:unrecognized_model]"

    public static func model(inStderr text: String) -> String? {
        guard let found = text.range(of: marker) else { return nil }
        let line = text[found.upperBound...].prefix { !$0.isNewline }
        return JSONValue.parse(Data(line.utf8))?["model"]?.stringValue ?? ""
    }
}
