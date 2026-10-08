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
        guard keyCode == Self.keyCode, !hasCommand, !hasControl else { return nil }
        var pressed: MenuShortcut.Modifiers = []
        if hasOption { pressed.insert(.option) }
        if hasShift { pressed.insert(.shift) }
        return declared.first { $0.key.trigger == .tab && $0.key.modifiers == pressed }?.offset
    }

    static let directions: [(action: MenuBarAction, offset: Int)] =
        [(.nextTab, 1), (.previousTab, -1)]

    private static let declared: [(key: MenuShortcut, offset: Int)] =
        directions.compactMap { direction in
            MenuBarCatalogue[direction.action].alternateKey.map {
                (key: $0, offset: direction.offset)
            }
        }
}
