import Foundation

@MainActor
public final class SingleFlight {
    private var task: Task<Void, Never>?

    public init() {}

    public func run(_ work: @escaping @Sendable @MainActor () async -> Void) async {
        if let task {
            await task.value
            return
        }

        let task = Task { await work() }
        self.task = task
        await task.value
        if self.task == task { self.task = nil }
    }

    public func wait() async {
        await task?.value
    }
}
