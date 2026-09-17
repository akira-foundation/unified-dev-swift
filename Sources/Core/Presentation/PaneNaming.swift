import Foundation

public enum PaneNaming {
    public static let chat = "Chat"
    public static let terminal = "Terminal"
    public static let browser = "Browser"

    public static let untitledChat = "Untitled"

    public static let missingTab = "Tab"

    public static func nextTitle(base: String, taken: some Sequence<String>) -> String {
        let taken = Set(taken)
        guard taken.contains(base) else { return base }
        var index = 2
        while taken.contains("\(base) \(index)") { index += 1 }
        return "\(base) \(index)"
    }

    public static func isDefaultTitle(_ title: String, base: String) -> Bool {
        if title == base { return true }
        guard title.hasPrefix(base + " ") else { return false }
        return Int(title.dropFirst(base.count + 1)) != nil
    }
}
