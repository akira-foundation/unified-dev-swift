import Foundation

public struct HexColor: Sendable, Hashable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }

        let digits = text.compactMap(\.hexDigitValue)
        guard digits.count == text.count else { return nil }

        switch digits.count {
        case 3:
            self.init(
                red: UInt8(digits[0] * 17),
                green: UInt8(digits[1] * 17),
                blue: UInt8(digits[2] * 17)
            )
        case 6:
            self.init(
                red: UInt8(digits[0] * 16 + digits[1]),
                green: UInt8(digits[2] * 16 + digits[3]),
                blue: UInt8(digits[4] * 16 + digits[5])
            )
        default:
            return nil
        }
    }
}
