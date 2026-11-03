import Foundation

public struct CanvasColour: Sendable, Hashable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public init?(_ text: String) {
        guard text.hasPrefix("#") else { return nil }
        let digits = Array(text.dropFirst())
        guard digits.count == 6 || digits.count == 8, digits.allSatisfy(\.isHexDigit) else { return nil }
        let bytes = stride(from: 0, to: digits.count, by: 2).compactMap {
            UInt8(String(digits[$0...$0 + 1]), radix: 16)
        }
        guard bytes.count == digits.count / 2 else { return nil }
        self.init(
            red: Double(bytes[0]) / 255,
            green: Double(bytes[1]) / 255,
            blue: Double(bytes[2]) / 255,
            alpha: bytes.count == 4 ? Double(bytes[3]) / 255 : 1
        )
    }

    public var hex: String {
        let bytes = [red, green, blue].map { Self.byte($0) }
        let base = String(format: "#%02X%02X%02X", bytes[0], bytes[1], bytes[2])
        return alpha < 1 ? base + String(format: "%02X", Self.byte(alpha)) : base
    }

    private static func byte(_ value: Double) -> Int {
        Int((min(max(value, 0), 1) * 255).rounded())
    }
}
