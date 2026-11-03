import Foundation

@MainActor
public final class CanvasCoalescedCommit {
    private let delay: Duration
    private var pending: (() -> Void)?
    private var timer: Task<Void, Never>?

    public init(delay: Duration = .milliseconds(300)) {
        self.delay = delay
    }

    public func schedule(_ action: @escaping () -> Void) {
        pending = action
        timer?.cancel()
        timer = Task { [weak self, delay] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    public func flush() {
        timer?.cancel()
        timer = nil
        let action = pending
        pending = nil
        action?()
    }
}
