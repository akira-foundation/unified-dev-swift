import Foundation

public enum QuickPromptSeed {
    public struct Entry: Sendable, Hashable {
        public var name: String
        public var symbol: String
        public var text: String
        public var introducedIn: Int

        public init(name: String, symbol: String, text: String, introducedIn: Int) {
            self.name = name
            self.symbol = symbol
            self.text = text
            self.introducedIn = introducedIn
        }

        public func prompt(sortOrder: Int, now: Date = Date()) -> QuickPrompt {
            QuickPrompt(
                name: name, symbol: symbol, text: text, sortOrder: sortOrder, createdAt: now
            )
        }
    }

    public static let versionKey = "quickPrompts.seedVersion"

    public static var version: Int { all.map(\.introducedIn).max() ?? 0 }

    public static let all: [Entry] = [
        Entry(
            name: "Explain changes",
            symbol: "doc.richtext",
            text: """
            Explain the changes made in this PR as HTML. Open it as a new tab in this workspace.
            """,
            introducedIn: 1
        ),
    ]

    public static func pending(installed: Int) -> [Entry] {
        all.filter { $0.introducedIn > installed }
    }
}
