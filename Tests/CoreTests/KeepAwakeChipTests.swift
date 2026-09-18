import Foundation
import Testing
@testable import Core

@Suite("Keep Awake chip")
struct KeepAwakeChipTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func tap(_ session: KeepAwakeSession?) -> [KeepAwakeChip.Action] {
        KeepAwakeChip.tap(session: session, at: now)
    }

    @Test("a tap with no session running keeps the Mac awake until it is turned off")
    func tapWhenOff() {
        #expect(tap(nil) == [.start(nil)])
        #expect(tap(.lasting(60, from: now.addingTimeInterval(-3600))) == [.start(nil)])
    }

    @Test("a tap on a running session stops only the session, never the setting for agents")
    func tapWhenOn() {
        #expect(tap(.lasting(3600, from: now)) == [.stop])
        #expect(tap(.indefinitely(from: now)) == [.stop])
    }

    @Test("the chip is on while a session runs, whatever the agents are doing")
    func isOn() {
        #expect(KeepAwakeChip.isOn(session: .indefinitely(from: now), at: now))
        #expect(!KeepAwakeChip.isOn(session: .lasting(60, from: now.addingTimeInterval(-3600)), at: now))
        #expect(!KeepAwakeChip.isOn(session: nil, at: now))
    }

    @Test("each choice starts what it names")
    func choices() {
        #expect(KeepAwakeChip.choose(.oneHour, whileAgentsRun: false) == [.start(3600)])
        #expect(KeepAwakeChip.choose(.twoHours, whileAgentsRun: false) == [.start(7200)])
        #expect(KeepAwakeChip.choose(.always, whileAgentsRun: true) == [.start(nil)])
    }

    @Test("until agents finish replaces a session, and choosing it again turns it off")
    func untilAgentsFinish() {
        #expect(KeepAwakeChip.choose(.untilAgentsFinish, whileAgentsRun: false) == [.stop, .setWhileAgentsRun(true)])
        #expect(KeepAwakeChip.choose(.untilAgentsFinish, whileAgentsRun: true) == [.setWhileAgentsRun(false)])
    }

    @Test("the options tick every rule that is on, the session by its length")
    func chosen() {
        let open = KeepAwakeSession.indefinitely(from: now)
        let hour = KeepAwakeSession.lasting(3600, from: now)
        let later = now.addingTimeInterval(1800)
        #expect(KeepAwakeChip.isChosen(.always, session: open, whileAgentsRun: false, at: now))
        #expect(!KeepAwakeChip.isChosen(.always, session: hour, whileAgentsRun: false, at: now))
        #expect(KeepAwakeChip.isChosen(.oneHour, session: hour, whileAgentsRun: false, at: later))
        #expect(!KeepAwakeChip.isChosen(.twoHours, session: hour, whileAgentsRun: false, at: later))
        #expect(!KeepAwakeChip.isChosen(.oneHour, session: hour, whileAgentsRun: false, at: now.addingTimeInterval(3601)))
        #expect(KeepAwakeChip.isChosen(.untilAgentsFinish, session: nil, whileAgentsRun: true, at: now))
        #expect(!KeepAwakeChip.isChosen(.untilAgentsFinish, session: nil, whileAgentsRun: false, at: now))
        #expect(KeepAwakeChip.isChosen(.always, session: open, whileAgentsRun: true, at: now))
        #expect(KeepAwakeChip.isChosen(.untilAgentsFinish, session: open, whileAgentsRun: true, at: now))
    }

    @Test("the chip's line agrees with its switch when only agents hold the Mac")
    func detail() {
        #expect(KeepAwakeChip.detail(session: nil, hold: .whileAgentsRun, whileAgentsRun: true, at: now)
            == KeepAwakeChip.agentsHoldDetail)
        #expect(KeepAwakeChip.detail(session: .indefinitely(from: now), hold: .indefinitely, whileAgentsRun: true, at: now)
            == "Until you stop it")
        #expect(KeepAwakeChip.detail(session: nil, hold: .none, whileAgentsRun: false, at: now)
            == "Nothing keeps this Mac awake")
    }

    @Test("the options read as the owner approved them")
    func titles() {
        #expect(KeepAwakeChoice.allCases.map(\.title) == ["1 hour", "2 hours", "Until agents finish", "Always"])
    }
}
