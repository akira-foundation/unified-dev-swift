import Foundation

public enum ThinkingText {
    public static func displayed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func tail(_ text: String, limit: Int) -> String {
        guard text.utf8.count > limit else { return displayed(text) }
        let kept = text.suffix(limit)
        guard kept.startIndex != text.startIndex else { return displayed(text) }
        let shown = displayed(String(kept))
        return shown.isEmpty ? "" : "\u{2026}" + shown
    }
}
