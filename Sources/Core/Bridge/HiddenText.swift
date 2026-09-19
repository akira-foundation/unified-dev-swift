import Foundation

public enum HiddenText {
    public static func hides(_ text: String) -> Bool {
        text.unicodeScalars.contains(where: isHiding)
    }

    public static func hasControls(_ text: String) -> Bool {
        text.unicodeScalars.contains { $0.value < 0x20 || (0x7F...0x9F).contains($0.value) || isHiding($0) }
    }

    static func isHiding(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0xE0000...0xE007F, 0x202A...0x202E, 0x2066...0x2069, 0x200E, 0x200F, 0x061C: true
        default: false
        }
    }
}
