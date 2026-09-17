import Foundation

public enum PromptAttachments {
    public static let folder = WorktreeScratch.attachments

    public static func newShortID() -> String {
        let alphabet = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in alphabet.randomElement() ?? "a" })
    }

    public static func safeFilename(_ name: String) -> String {
        var cleaned = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        while cleaned.hasPrefix(".") { cleaned.removeFirst() }
        guard !cleaned.isEmpty else { return "attachment" }
        return cleaned
    }

    public static func destination(filename: String, id: String) -> String {
        "\(folder)/\(id)/\(safeFilename(filename))"
    }
}
