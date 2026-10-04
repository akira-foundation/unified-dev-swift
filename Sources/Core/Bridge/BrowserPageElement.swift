import Foundation

public struct BrowserPageElement: Sendable, Equatable, Decodable {
    public let role: String
    public let name: String
    public let value: String?
    public let isPassword: Bool
    public let valueLength: Int
    public let isDisabled: Bool
    public let isChecked: Bool?
    public let depth: Int

    public init(
        role: String,
        name: String,
        value: String? = nil,
        isPassword: Bool = false,
        valueLength: Int = 0,
        isDisabled: Bool = false,
        isChecked: Bool? = nil,
        depth: Int = 0
    ) {
        self.role = role
        self.name = name
        self.value = value
        self.isPassword = isPassword
        self.valueLength = valueLength
        self.isDisabled = isDisabled
        self.isChecked = isChecked
        self.depth = depth
    }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        role = try fields.decode(String.self, forKey: .role)
        name = try fields.decode(String.self, forKey: .name)
        value = try fields.decodeIfPresent(String.self, forKey: .value)
        isPassword = try fields.decodeIfPresent(Bool.self, forKey: .isPassword) ?? false
        valueLength = try fields.decodeIfPresent(Int.self, forKey: .valueLength) ?? 0
        isDisabled = try fields.decodeIfPresent(Bool.self, forKey: .isDisabled) ?? false
        isChecked = try fields.decodeIfPresent(Bool.self, forKey: .isChecked)
        depth = try fields.decodeIfPresent(Int.self, forKey: .depth) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case role
        case name
        case value
        case isPassword
        case valueLength
        case isDisabled
        case isChecked
        case depth
    }
}
