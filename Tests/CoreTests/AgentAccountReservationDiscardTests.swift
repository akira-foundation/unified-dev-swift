import Foundation
import Testing
@testable import Core

@Suite("Discarding a reservation an agent may still hold", .tags(.persistence), .scratchDirectory)
struct AgentAccountReservationDiscardTests {
    @Test func aReservationGoesOnceTheProcessHoldingItHasExited() async throws {
        let reservation = try AgentAccountCreation.reserve(
            provider: .claudeCode, label: "Client", existing: [], support: URL(filePath: TestScratch.unique("support"), directoryHint: .isDirectory)
        )
        let holder = ProcessVector(pid: 7, strings: ["X=\(reservation.plan.directory.path)"])
        let reads = Reads()

        let discarded = await reservation.discardOnceReleased(pause: .zero, processes: {
            reads.next() < 2 ? [holder] : []
        })

        #expect(discarded)
        #expect(!FileManager.default.fileExists(atPath: reservation.plan.directory.path))
    }

    @Test func aReservationStillHeldAfterEveryAttemptIsKept() async throws {
        let reservation = try AgentAccountCreation.reserve(
            provider: .claudeCode, label: "Client", existing: [], support: URL(filePath: TestScratch.unique("support"), directoryHint: .isDirectory)
        )
        let holder = ProcessVector(pid: 7, strings: ["X=\(reservation.plan.directory.path)"])
        let reads = Reads()

        let discarded = await reservation.discardOnceReleased(attempts: 3, pause: .zero, processes: {
            _ = reads.next()
            return [holder]
        })

        #expect(!discarded)
        #expect(reads.next() == 3)
        #expect(FileManager.default.fileExists(atPath: reservation.plan.directory.path))
    }

    @Test func aReservationIsKeptWhenTheProcessesCannotBeRead() throws {
        let reservation = try AgentAccountCreation.reserve(
            provider: .claudeCode, label: "Client", existing: [], support: URL(filePath: TestScratch.unique("support"), directoryHint: .isDirectory)
        )

        #expect(!reservation.discard(processes: { nil }))
        #expect(FileManager.default.fileExists(atPath: reservation.plan.directory.path))
    }

    @Test func aReservationOneProcessCannotBeReadIsKept() throws {
        let reservation = try AgentAccountCreation.reserve(
            provider: .claudeCode, label: "Client", existing: [], support: URL(filePath: TestScratch.unique("support"), directoryHint: .isDirectory)
        )

        #expect(!reservation.discard(processes: { [ProcessVector(pid: 7, strings: nil)] }))
        #expect(FileManager.default.fileExists(atPath: reservation.plan.directory.path))
    }
}
