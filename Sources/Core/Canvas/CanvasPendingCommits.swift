import Foundation

@MainActor
public final class CanvasPendingCommits {
    private struct Registered {
        weak var commit: CanvasCoalescedCommit?
    }

    private var registered: [Registered] = []

    public init() {}

    public func add(_ commit: CanvasCoalescedCommit) {
        registered.removeAll { $0.commit == nil || $0.commit === commit }
        registered.append(Registered(commit: commit))
    }

    public func flush() {
        for entry in registered { entry.commit?.flush() }
    }
}
