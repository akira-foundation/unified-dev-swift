import Foundation

public enum CodexContextWindow {
    public static let modelDefault = 0

    public static let choices = [modelDefault, 500_000, 1_000_000]

    static let compactAt = 0.9

    public static func autoCompactLimit(for tokens: Int) -> Int {
        guard tokens > 0 else { return 0 }
        return Int((Double(tokens) * compactAt).rounded())
    }

    public static func overrides(for tokens: Int) -> [String] {
        guard tokens > 0 else { return [] }
        return [
            "-c", "model_context_window=\(tokens)",
            "-c", "model_auto_compact_token_limit=\(autoCompactLimit(for: tokens))",
        ]
    }

    public static func label(for tokens: Int) -> String {
        guard tokens > 0 else { return "Default" }
        if tokens >= 1_000_000, tokens.isMultiple(of: 1_000_000) {
            return "\(tokens / 1_000_000)M"
        }
        if tokens >= 1_000, tokens.isMultiple(of: 1_000) {
            return "\(tokens / 1_000)K"
        }
        return "\(tokens)"
    }

    public static func options(including current: Int) -> [Int] {
        let wanted = max(modelDefault, current)
        guard wanted != modelDefault, !choices.contains(wanted) else { return choices }
        return (choices + [wanted]).sorted()
    }

    public static func normalised(_ raw: String?) -> Int {
        guard let raw, let tokens = Int(raw.trimmingCharacters(in: .whitespaces)), tokens > 0 else {
            return modelDefault
        }
        return tokens
    }

    public static func stored(_ tokens: Int) -> String? {
        tokens > 0 ? String(tokens) : nil
    }
}
