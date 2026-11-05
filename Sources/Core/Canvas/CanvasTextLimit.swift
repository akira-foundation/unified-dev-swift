import Foundation

enum CanvasTextLimit {
    static func length(of text: String) -> Int {
        text.unicodeScalars.count
    }

    static func cut(_ text: String, to limit: Int) -> String {
        guard length(of: text) > limit else { return text }
        var kept = String.UnicodeScalarView()
        kept.append(contentsOf: text.unicodeScalars.prefix(limit))
        return String(kept)
    }
}
