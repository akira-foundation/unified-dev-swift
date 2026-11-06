import Foundation

public extension PreviewScenario {
    struct Profile: Sendable, Equatable, Codable {
        public var name: String
        public var colour: String
        public var symbol: String
        public var accounts: ProfileAccountSource

        public init(name: String, colour: String, symbol: String, accounts: ProfileAccountSource = .own) {
            self.name = name
            self.colour = colour
            self.symbol = symbol
            self.accounts = accounts
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            colour = try container.decode(String.self, forKey: .colour)
            symbol = try container.decode(String.self, forKey: .symbol)
            accounts = try container.decodeIfPresent(ProfileAccountSource.self, forKey: .accounts) ?? .own
        }
    }
}
