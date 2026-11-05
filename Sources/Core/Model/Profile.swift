import Foundation

public struct Profile: Identifiable, Sendable, Hashable, Codable {
    public let id: ProfileID
    public var name: String
    public let folder: String
    public var colour: String
    public var symbol: String
    public var sortOrder: Int
    public let createdAt: Date

    public var isInitial: Bool { id == .initial }

    public var activeLabel: String { "Active profile, \(name)" }

    public init(
        id: ProfileID,
        name: String,
        folder: String,
        colour: String,
        symbol: String,
        sortOrder: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.folder = folder
        self.colour = colour
        self.symbol = symbol
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}
