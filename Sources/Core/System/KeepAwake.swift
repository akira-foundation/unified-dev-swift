import Foundation

public struct KeepAwakeSession: Sendable, Hashable, Codable {
    public var startedAt: Date
    public var until: Date?

    public init(startedAt: Date, until: Date?) {
        self.startedAt = startedAt
        self.until = until
    }

    public static func indefinitely(from now: Date) -> KeepAwakeSession {
        KeepAwakeSession(startedAt: now, until: nil)
    }

    public static func lasting(_ seconds: TimeInterval, from now: Date) -> KeepAwakeSession {
        KeepAwakeSession(startedAt: now, until: now.addingTimeInterval(seconds))
    }

    public func isActive(at now: Date) -> Bool {
        guard let until else { return true }
        return until > now
    }
}

public enum KeepAwake {
    public static let sessionKey = "system.keepAwakeSession"

    public static let lidKey = "system.keepAwakeWithLidClosed"

    public static let title = "Keep Awake"

    public static let menuBarSymbol = "cup.and.saucer.fill"

    public static func holdsAwake(
        session: KeepAwakeSession?,
        whileAgentsRun: Bool,
        runningCount: Int,
        at now: Date
    ) -> Bool {
        (session?.isActive(at: now) ?? false)
            || SleepPrevention.preventsSleep(isEnabled: whileAgentsRun, runningCount: runningCount)
    }

    public static func holdsLidClosed(session: KeepAwakeSession?, lidEnabled: Bool, at now: Date) -> Bool {
        lidEnabled && (session?.isActive(at: now) ?? false)
    }

    public struct Status: Sendable, Hashable {
        public var isOn: Bool
        public var headline: String
        public var detail: String
    }

    public static let onHeadline = "Keeping this Mac awake"
    public static let offHeadline = "Sleep allowed"

    public static func status(
        session: KeepAwakeSession?,
        whileAgentsRun: Bool,
        runningCount: Int,
        at now: Date,
        clock: UsageTimeFormat = .automatic,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> Status {
        if let session, session.isActive(at: now) {
            guard let until = session.until else {
                return Status(isOn: true, headline: onHeadline, detail: "Until you stop it")
            }
            let clockTime = UsageFormat.timeOfDay(until, clock: clock, calendar: calendar, locale: locale)
            let left = UsageFormat.compactDuration(until.timeIntervalSince(now))
            return Status(isOn: true, headline: onHeadline, detail: "\(left) left, until \(clockTime)")
        }
        if SleepPrevention.preventsSleep(isEnabled: whileAgentsRun, runningCount: runningCount) {
            let verb = runningCount == 1 ? "runs" : "run"
            return Status(isOn: true, headline: onHeadline, detail: "While \(Counted.of(runningCount, "agent")) \(verb)")
        }
        return Status(
            isOn: false,
            headline: offHeadline,
            detail: whileAgentsRun ? "Awake while agents run" : "Nothing keeps this Mac awake"
        )
    }

    public static func label(hours: Int) -> String { Counted.of(hours, "hour") }

    public static func load(from defaults: UserDefaults = .standard, at now: Date = Date()) -> KeepAwakeSession? {
        guard let data = defaults.data(forKey: sessionKey),
              let session = try? JSONDecoder().decode(KeepAwakeSession.self, from: data),
              session.isActive(at: now)
        else { return nil }
        return session
    }

    public static func save(_ session: KeepAwakeSession?, to defaults: UserDefaults = .standard) {
        guard let session, let data = try? JSONEncoder().encode(session) else {
            defaults.removeObject(forKey: sessionKey)
            return
        }
        defaults.set(data, forKey: sessionKey)
    }
}
