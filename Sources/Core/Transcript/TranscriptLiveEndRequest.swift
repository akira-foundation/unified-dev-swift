public struct TranscriptLiveEndRequest: Equatable, Sendable {
    public private(set) var handled: Int

    public init(handled: Int = 0) {
        self.handled = handled
    }

    public mutating func consume(_ requested: Int, isReady: Bool) -> Bool {
        guard isReady, requested > handled else { return false }
        handled = requested
        return true
    }
}
