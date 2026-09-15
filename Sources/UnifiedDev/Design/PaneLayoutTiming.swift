import Foundation
import QuartzCore

/// How long each pane spent in layout, while `FrameProbe` is measuring a drag.
///
/// Off unless a probe turned it on, and it reads one clock and adds to two doubles when it is on,
/// so nothing here is a cost the shipping app pays. It exists because "the drag is slow" and "the
/// centre column's layout is slow" are different claims, and only the second one can be acted on.
@MainActor
enum PaneLayoutTiming {
    static var isEnabled = false
    private static var counts: [String: Int] = [:]
    private static var seconds: [String: Double] = [:]

    /// When each pass started, measured from `reset`, and how long it took. A total says a switch
    /// is expensive; the passes say it is expensive four times over, which is a different problem
    /// with a different fix.
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

    /// Every pass, as `[startedMs, tookMs]`, for a report that has to say when as well as how long.
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

// The hosting view that fed this went with `DetailSplitViewController`: it timed the two panes of
// a split view of ours, and the inspector is a column of the window now. What is left is the
// ledger, which `FrameProbe` and `ResizeProbe` still read, and which stays empty until something
// records into it again.
