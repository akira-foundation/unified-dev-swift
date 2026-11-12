import Foundation

public enum TerminalActivitySchedule {
    public static let foregroundTick: Duration = .seconds(2)

    public static let backgroundTick: Duration = .seconds(10)

    public static let runScriptForegroundTick: Duration = .seconds(1)

    public static let readingMaxAge: Duration = .seconds(2)

    public static let commandRecordInterval: Duration = .seconds(30)

    public static func tick(isAppActive: Bool) -> Duration {
        isAppActive ? foregroundTick : backgroundTick
    }

    public static func runScriptTick(isAppActive: Bool) -> Duration {
        isAppActive ? runScriptForegroundTick : backgroundTick
    }

    public static func isRecordDue(lastRecorded: ContinuousClock.Instant, now: ContinuousClock.Instant) -> Bool {
        now - lastRecorded >= commandRecordInterval
    }
}
