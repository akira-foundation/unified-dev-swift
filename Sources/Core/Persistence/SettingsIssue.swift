import Foundation

public struct SettingsIssue: Sendable, Hashable {
    public enum Entry: Sendable, Hashable {
        case file
        case runScript(String)
        case quickPrompt(index: Int, name: String?)
    }

    public var path: String
    public var message: String
    public var entry: Entry
    public var line: Int?

    public init(path: String, message: String, entry: Entry, line: Int? = nil) {
        self.path = path
        self.message = message
        self.entry = entry
        self.line = line
    }
}
