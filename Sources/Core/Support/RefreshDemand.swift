public struct RefreshDemand: Sendable {
    public private(set) var isRunning = false
    private var isPending = false

    public init() {}

    public mutating func request() -> Bool {
        guard !isRunning else {
            isPending = true
            return false
        }
        isRunning = true
        return true
    }

    public mutating func complete() -> Bool {
        guard isPending else {
            isRunning = false
            return false
        }
        isPending = false
        return true
    }
}
