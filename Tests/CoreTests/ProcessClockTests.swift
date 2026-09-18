import Testing
import Foundation
@testable import Core

@Suite("Process clock")
struct ProcessClockTests {
    @Test("reports a duration this process has already lived, and never goes backwards")
    func countsForwardFromProcessCreation() {
        let first = ProcessClock.millisecondsSinceStart()
        #expect(first >= 0)

        let second = ProcessClock.millisecondsSinceStart()
        #expect(second >= first)
    }

    @Test("two readings grow by the wall clock time between them")
    func tracksTheWallClock() async throws {
        let firstReading = ProcessClock.millisecondsSinceStart()
        let firstWall = Date()
        try await Task.sleep(for: .milliseconds(30))
        let secondReading = ProcessClock.millisecondsSinceStart()
        let elapsed = Date().timeIntervalSince(firstWall) * 1000
        let grew = Double(secondReading - firstReading)

        #expect(grew >= 20)
        #expect(grew <= elapsed + 5)
    }
}
