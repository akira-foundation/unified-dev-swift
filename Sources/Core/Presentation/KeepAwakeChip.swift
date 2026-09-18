import Foundation

public enum KeepAwakeChoice: String, CaseIterable, Sendable, Identifiable {
    case oneHour
    case twoHours
    case untilAgentsFinish
    case always

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .oneHour: KeepAwake.label(hours: 1)
        case .twoHours: KeepAwake.label(hours: 2)
        case .untilAgentsFinish: "Until agents finish"
        case .always: "Always"
        }
    }

    public var duration: TimeInterval? {
        switch self {
        case .oneHour: 3600
        case .twoHours: 7200
        case .untilAgentsFinish, .always: nil
        }
    }
}

public enum KeepAwakeChip {
    public enum Action: Equatable, Sendable {
        case start(TimeInterval?)
        case stop
        case setWhileAgentsRun(Bool)
    }

    public static let optionsLabel = "Keep Awake options"
    public static let settingsTitle = "Keep Awake Settings\u{2026}"

    public static func isOn(session: KeepAwakeSession?, at now: Date) -> Bool {
        session?.isActive(at: now) ?? false
    }

    public static func tap(session: KeepAwakeSession?, at now: Date) -> [Action] {
        isOn(session: session, at: now) ? [.stop] : [.start(nil)]
    }

    public static let agentsHoldDetail = "Off, agents keep this Mac awake"

    public static func detail(
        session: KeepAwakeSession?,
        hold: KeepAwake.Hold,
        whileAgentsRun: Bool,
        at now: Date
    ) -> String {
        guard !isOn(session: session, at: now), hold == .whileAgentsRun else {
            return KeepAwake.status(session: session, whileAgentsRun: whileAgentsRun, runningCount: 0, at: now).detail
        }
        return agentsHoldDetail
    }

    public static func choose(_ choice: KeepAwakeChoice, whileAgentsRun: Bool) -> [Action] {
        switch choice {
        case .oneHour, .twoHours, .always: [.start(choice.duration)]
        case .untilAgentsFinish: whileAgentsRun ? [.setWhileAgentsRun(false)] : [.stop, .setWhileAgentsRun(true)]
        }
    }

    public static func isChosen(
        _ choice: KeepAwakeChoice,
        session: KeepAwakeSession?,
        whileAgentsRun: Bool,
        at now: Date
    ) -> Bool {
        guard choice != .untilAgentsFinish else { return whileAgentsRun }
        guard let session, session.isActive(at: now) else { return false }
        return session.until.map { $0.timeIntervalSince(session.startedAt) } == choice.duration
    }
}
