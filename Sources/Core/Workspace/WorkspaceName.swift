import Foundation

public enum WorkspaceName {
    public static let limit = 80

    public static func given(_ raw: String?) -> String? {
        guard let raw else { return nil }
        var visible = String.UnicodeScalarView()
        visible.append(contentsOf: raw.unicodeScalars.compactMap(kept))
        let words = String(visible).split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let bounded = String(words.prefix(limit)).trimmingCharacters(in: .whitespaces)
        return bounded.isEmpty ? nil : bounded
    }

    static func kept(_ scalar: Unicode.Scalar) -> Unicode.Scalar? {
        switch scalar.properties.generalCategory {
        case .control, .lineSeparator, .paragraphSeparator: " "
        case .format, .privateUse, .surrogate, .unassigned: nil
        default: scalar
        }
    }
}
