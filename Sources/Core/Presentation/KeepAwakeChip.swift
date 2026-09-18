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

    public static func choose(_ choice: KeepAwakeChoice, whileAgentsRun: Bool) -> [Action] {
        switch choice {
        case .oneHour: [.start(3600)]
        case .twoHours: [.start(7200)]
        case .always: [.start(nil)]
        case .untilAgentsFinish: whileAgentsRun ? [.setWhileAgentsRun(false)] : [.stop, .setWhileAgentsRun(true)]
        }
    }

    public static func isChosen(
        _ choice: KeepAwakeChoice,
        session: KeepAwakeSession?,
        whileAgentsRun: Bool,
        at now: Date
    ) -> Bool {
        switch choice {
        case .always:
            guard let session, session.isActive(at: now) else { return false }
            return session.until == nil
        case .untilAgentsFinish:
            return whileAgentsRun
        case .oneHour, .twoHours:
            return false
        }
    }
}
