import Foundation

public enum ProbeStats {
    public static func percentile(_ fraction: Double, of sorted: [Double]) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let last = Double(sorted.count - 1)
        let rank = min(last, max(0, (last * fraction).rounded()))
        return sorted[Int(rank)]
    }

    public static func windowSize(_ raw: String) -> CGSize? {
        let parts = raw.split(separator: "x")
        guard parts.count == 2,
              let width = Double(parts[0]), let height = Double(parts[1]),
              width > 0, height > 0
        else { return nil }
        return CGSize(width: width, height: height)
    }
}
