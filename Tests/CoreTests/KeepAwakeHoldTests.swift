import Foundation
import Testing
@testable import Core

@Suite("Keep Awake hold")
struct KeepAwakeHoldTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("a timed session holds until its end, an open one holds indefinitely")
    func sessions() {
        let timed = KeepAwake.Hold.of(
            session: .lasting(3600, from: now), whileAgentsRun: false, runningCount: 0, at: now
        )
        #expect(timed == .until(now.addingTimeInterval(3600)))
        let open = KeepAwake.Hold.of(
            session: .indefinitely(from: now), whileAgentsRun: true, runningCount: 2, at: now
        )
        #expect(open == .indefinitely)
    }

    @Test("with no session, running agents hold the Mac only when the setting is on")
    func agents() {
        let spent = KeepAwakeSession.lasting(60, from: now.addingTimeInterval(-3600))
        #expect(KeepAwake.Hold.of(session: spent, whileAgentsRun: true, runningCount: 1, at: now) == .whileAgentsRun)
        #expect(KeepAwake.Hold.of(session: nil, whileAgentsRun: false, runningCount: 3, at: now) == .none)
        #expect(KeepAwake.Hold.of(session: nil, whileAgentsRun: true, runningCount: 0, at: now) == .none)
    }

    @Test("only nothing at all counts as off")
    func isOn() {
        #expect(!KeepAwake.Hold.none.isOn)
        #expect(KeepAwake.Hold.whileAgentsRun.isOn)
        #expect(KeepAwake.Hold.indefinitely.isOn)
        #expect(KeepAwake.Hold.until(now).isOn)
    }
}
