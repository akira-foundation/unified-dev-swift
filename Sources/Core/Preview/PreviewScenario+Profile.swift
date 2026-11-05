import Foundation

public extension PreviewScenario {
    struct Profile: Sendable, Equatable, Codable {
        public var name: String
        public var colour: String
        public var symbol: String

        public init(name: String, colour: String, symbol: String) {
            self.name = name
            self.colour = colour
            self.symbol = symbol
        }
    }
}
