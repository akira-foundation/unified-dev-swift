import Foundation

public enum SpendChartScale {
    public static func barWidth(for bars: Int) -> Double {
        switch bars {
        case ..<8: 18
        case ..<15: 11
        default: 7
        }
    }

    public static func labelStride(for bars: Int) -> Int {
        bars > 10 ? 7 : 1
    }

    public static func labelled(_ days: [Date], naming: (Date) -> String) -> [String] {
        let step = labelStride(for: days.count)
        return days.enumerated()
            .filter { (days.count - 1 - $0.offset) % step == 0 }
            .map { naming($0.element) }
    }
}
