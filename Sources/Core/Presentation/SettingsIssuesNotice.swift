import Foundation

public struct SettingsIssuesNotice: Sendable, Hashable {
    public var title: String
    public var messages: [String]
    public var path: String
    public var line: Int?
    public var signature: [String]

    static let shownMessages = 2

    public static func make(issues: [SettingsIssue]) -> SettingsIssuesNotice? {
        guard let first = issues.first else { return nil }
        let files = Set(issues.map(\.path))
        let place = files.count == 1 ? displayName(of: first.path) : "the settings files"

        let title: String
        if issues.count == 1, first.entry == .file {
            title = "\(place) could not be read"
        } else {
            let entries = issues.count == 1 ? "1 entry" : "\(issues.count) entries"
            let verb = issues.count == 1 ? "was" : "were"
            title = "\(entries) in \(place) \(verb) skipped"
        }

        var messages = issues.prefix(shownMessages).map(\.message)
        let rest = issues.count - messages.count
        if rest > 0 { messages.append(rest == 1 ? "And 1 more." : "And \(rest) more.") }

        return SettingsIssuesNotice(
            title: title,
            messages: messages,
            path: first.path,
            line: first.line,
            signature: issues.map { "\($0.path)\n\($0.message)" }
        )
    }

    static func displayName(of path: String) -> String {
        let components = (path as NSString).pathComponents
        return components.suffix(2).joined(separator: "/")
    }
}
