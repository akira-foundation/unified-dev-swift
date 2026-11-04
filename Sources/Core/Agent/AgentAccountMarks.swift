import Foundation

public struct AgentAccountMarks: Sendable, Equatable {
    public static let switchWindow: TimeInterval = 900

    private var signedOut: [AgentAccountID: AgentAccountSignOut.Cause] = [:]
    private var switched: (account: AgentAccountID, at: Date)?

    public init() {}

    public static func == (lhs: AgentAccountMarks, rhs: AgentAccountMarks) -> Bool {
        lhs.signedOut == rhs.signedOut
            && lhs.switched?.account == rhs.switched?.account
            && lhs.switched?.at == rhs.switched?.at
    }

    public func cause(for account: AgentAccountID) -> AgentAccountSignOut.Cause? {
        signedOut[account]
    }

    public mutating func noteSwitched(to account: AgentAccountID, at now: Date) {
        switched = (account, now)
    }

    public mutating func noteChosen() {
        switched = nil
    }

    public mutating func apply(
        _ observation: AgentAccountSignOut.Observation,
        on account: AgentAccountID,
        at now: Date
    ) {
        switch observation {
        case .none:
            return
        case .working:
            signedOut[account] = nil
            if switched?.account == account { switched = nil }
        case .signedOut:
            signedOut[account] = isJustSwitchedTo(account, at: now) ? .afterSwitch : .notSignedIn
        }
    }

    private func isJustSwitchedTo(_ account: AgentAccountID, at now: Date) -> Bool {
        guard let switched, switched.account == account else { return false }
        return now.timeIntervalSince(switched.at) <= Self.switchWindow
    }
}
