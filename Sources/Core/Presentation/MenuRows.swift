import Foundation

public enum MenuRows {
    public static func stepped<Row: Equatable>(
        from current: Row?, by step: Int, in rows: [Row]
    ) -> Row? {
        guard !rows.isEmpty else { return nil }
        guard let current, let index = rows.firstIndex(of: current) else {
            return step < 0 ? rows.last : rows.first
        }
        return rows[(index + step + rows.count) % rows.count]
    }
}
