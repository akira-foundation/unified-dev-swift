import Foundation

public enum TabCycleStroke {
    public static let keyCode: UInt16 = 48

    public static func offset(
        keyCode: UInt16,
        hasOption: Bool,
        hasShift: Bool,
        hasCommand: Bool,
        hasControl: Bool
    ) -> Int? {
        guard keyCode == Self.keyCode, hasOption, !hasCommand, !hasControl else { return nil }
        return hasShift ? -1 : 1
    }
}
