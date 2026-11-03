public enum SettingsColumn {
    public static let width = 680.0

    public static func sideMargin(in available: Double, column: Double?) -> Double {
        guard let column else { return 0 }
        return max(0, (available - column) / 2)
    }
}
