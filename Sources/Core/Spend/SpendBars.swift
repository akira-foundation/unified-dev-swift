import Foundation

public enum SpendBars {
    public static let floor = 0.08

    public static func heights(of bars: [SpendBoard.DayBar]) -> [Double] {
        let highest = bars.map(\.spend.cost.total).max() ?? 0
        guard highest > 0 else { return bars.map { _ in 0 } }
        return bars.map { bar in
            let cost = bar.spend.cost.total
            guard cost > 0 else { return 0 }
            return max(floor, min(1, cost / highest))
        }
    }

    public static func dearest(_ bars: [SpendBoard.DayBar]) -> SpendBoard.DayBar? {
        bars.max { $0.spend.cost.total < $1.spend.cost.total }
    }
}
