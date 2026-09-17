import Foundation

public struct StoredPaneArrangement: Codable, Sendable, Equatable {
    public var layout: String

    public var contents: [String: PaneContent]

    public init(layout: String, contents: [String: PaneContent]) {
        self.layout = layout
        self.contents = contents
    }

    public var encoded: Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try? encoder.encode(self)
    }

    public init?(decoding data: Data) {
        guard let value = try? JSONDecoder().decode(Self.self, from: data) else { return nil }
        self = value
    }

    public func claimedContents(root: PaneContent) -> Set<PaneContent> {
        Set(contents.values).subtracting([root])
    }
}
