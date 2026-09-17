import Foundation
import QuartzCore

@MainActor
enum PaneLayoutTiming {
    static var isEnabled = false
    private static var counts: [String: Int] = [:]
    private static var seconds: [String: Double] = [:]

    private static var passes: [String: [[Double]]] = [:]
    private static var origin: Double = 0

    static func reset() {
        counts.removeAll()
        seconds.removeAll()
        passes.removeAll()
        origin = CACurrentMediaTime()
    }

    static func record(_ pane: String, _ elapsed: Double) {
        counts[pane, default: 0] += 1
        seconds[pane, default: 0] += elapsed
        passes[pane, default: []].append([
            (CACurrentMediaTime() - elapsed - origin) * 1000, elapsed * 1000,
        ])
    }

    static func timeline() -> [String: [[Double]]] { passes }

    static func summary() -> [String: [String: Double]] {
        var result: [String: [String: Double]] = [:]
        for (pane, total) in seconds {
            let count = Double(counts[pane] ?? 0)
            result[pane] = [
                "passes": count,
                "totalMs": total * 1000,
                "meanMs": count > 0 ? total * 1000 / count : 0,
            ]
        }
        return result
    }
}
