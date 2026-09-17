import Foundation
import Testing
@testable import Core

@Suite("Waiting for a process that may already have exited")
struct ProcessExitGateTests {
    @Test("a signal that arrives before anybody waits is remembered")
    func signalBeforeWait() async {
        let gate = ProcessExitGate()
        gate.signal()
        await gate.wait()
    }

    @Test("a waiter parked first is resumed by the signal")
    func waitBeforeSignal() async {
        let gate = ProcessExitGate()
        async let waited: Void = gate.wait()
        try? await Task.sleep(for: .milliseconds(20))
        gate.signal()
        await waited
    }

    @Test("signalling twice does not resume a continuation twice")
    func signalIsIdempotent() async {
        let gate = ProcessExitGate()
        async let waited: Void = gate.wait()
        try? await Task.sleep(for: .milliseconds(20))
        gate.signal()
        gate.signal()
        await waited
        gate.signal()
    }

    @Test("a real short lived process is waited on rather than hung on")
    func realProcessThatExitsImmediately() async throws {
        for _ in 0..<25 {
            let result = try await Shell.run("/usr/bin/true", [])
            #expect(result.ok)
        }
    }
}
