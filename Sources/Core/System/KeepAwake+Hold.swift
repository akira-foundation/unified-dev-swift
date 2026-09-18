import Foundation

extension KeepAwake {
    public enum Hold: Equatable, Sendable {
        case none
        case whileAgentsRun
        case until(Date)
        case indefinitely

        public static func of(
            session: KeepAwakeSession?,
            whileAgentsRun: Bool,
            runningCount: Int,
            at now: Date
        ) -> Hold {
            if let session, session.isActive(at: now) {
                return session.until.map(Hold.until) ?? .indefinitely
            }
            return SleepPrevention.preventsSleep(isEnabled: whileAgentsRun, runningCount: runningCount)
                ? .whileAgentsRun
                : .none
        }

        public var isOn: Bool { self != .none }
    }
}
