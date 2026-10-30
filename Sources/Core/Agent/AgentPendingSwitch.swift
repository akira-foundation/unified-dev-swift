import Foundation

public struct AgentPendingSwitch: Sendable, Equatable {
    public struct Launch: Sendable, Equatable {
        public let account: AgentAccountHome?
        public let isDeliberateSwitch: Bool
    }

    public private(set) var destination: AgentAccountHome?

    public init() {}

    public mutating func intend(_ destination: AgentAccountHome) {
        self.destination = destination
    }

    public mutating func drop() {
        destination = nil
    }

    public func launch(resolved: AgentAccountHome?) -> Launch {
        guard let destination, destination.id == resolved?.id else {
            return Launch(account: resolved, isDeliberateSwitch: false)
        }
        return Launch(account: destination, isDeliberateSwitch: true)
    }

    public mutating func settled(by reuse: AgentRunnerReuse, for purpose: AgentSessionSettlement.Purpose) {
        guard reuse.appliesSettlement(for: purpose) else { return }
        destination = nil
    }
}
