import Foundation
import Testing
@testable import Core

@Suite("CheckState", .tags(.agentProtocol))
struct CheckStateTests {
    @Test("an empty conclusion is no conclusion, and the status decides", arguments: [
        (status: "QUEUED", state: CheckState.queued),
        (status: "WAITING", state: .queued),
        (status: "REQUESTED", state: .queued),
        (status: "IN_PROGRESS", state: .running),
        (status: "PENDING", state: .running),
        (status: "COMPLETED", state: .neutral),
    ])
    func emptyConclusion(status: String, state: CheckState) {
        #expect(CheckState(CheckRun(name: "unittest", status: status, conclusion: "")) == state)
        #expect(CheckState(CheckRun(name: "unittest", status: status, conclusion: nil)) == state)
    }

    @Test("a conclusion, once there is one, outranks the status", arguments: [
        (conclusion: "SUCCESS", state: CheckState.passed),
        (conclusion: "success", state: .passed),
        (conclusion: "SKIPPED", state: .skipped),
        (conclusion: "NEUTRAL", state: .neutral),
        (conclusion: "FAILURE", state: .failed),
        (conclusion: "TIMED_OUT", state: .failed),
        (conclusion: "CANCELLED", state: .failed),
        (conclusion: "ACTION_REQUIRED", state: .failed),
        (conclusion: "STARTUP_FAILURE", state: .failed),
        (conclusion: "STALE", state: .failed),
        (conclusion: "SOMETHING_NEW", state: .neutral),
    ])
    func withConclusion(conclusion: String, state: CheckState) {
        #expect(CheckState(CheckRun(name: "unittest", status: "COMPLETED", conclusion: conclusion)) == state)
    }

    @Test("a commit status reports being in flight through its conclusion", arguments: [
        (state: "PENDING", expected: CheckState.running),
        (state: "EXPECTED", expected: .queued),
        (state: "QUEUED", expected: .queued),
    ])
    func commitStatus(state: String, expected: CheckState) {
        #expect(CheckState(CheckRun(name: "coverage", status: "PENDING", conclusion: state)) == expected)
    }

    @Test("gh's own JSON for a branch mid-run tells the two apart")
    func liveShape() throws {
        let runs = try GitHub.decodeChecks(from: Data("""
        {"number":1,"title":"PR","url":"https://example/1","state":"OPEN","statusCheckRollup":[
          {"__typename":"CheckRun","completedAt":"0001-01-01T00:00:00Z","conclusion":"","detailsUrl":"https://example/a","name":"lint","startedAt":"0001-01-01T00:00:00Z","status":"QUEUED","workflowName":"tests"},
          {"__typename":"CheckRun","completedAt":"0001-01-01T00:00:00Z","conclusion":"","detailsUrl":"https://example/b","name":"unittest","startedAt":"2026-08-19T17:04:11Z","status":"IN_PROGRESS","workflowName":"tests"},
          {"__typename":"CheckRun","completedAt":"2026-08-19T17:04:17Z","conclusion":"SUCCESS","detailsUrl":"https://example/c","name":"build","startedAt":"2026-08-19T17:04:11Z","status":"COMPLETED","workflowName":"tests"}
        ]}
        """.utf8))

        #expect(runs.map(CheckState.init) == [.queued, .running, .passed])
        #expect(runs[0].startedAt == nil)
        #expect(runs[0].completedAt == nil)
        #expect(runs[1].startedAt != nil)
        #expect(runs[1].completedAt == nil)
        #expect(runs[2].completedAt != nil)
    }

    @Test("every state says what it is out loud")
    func spoken() {
        #expect(CheckState.queued.description == "Queued")
        #expect(CheckState.running.description == "Running")
        #expect(CheckState.neutral.description == "No result")
    }

    private static let all: [CheckState] = [.queued, .running, .passed, .failed, .skipped, .neutral]

    @Test("six states, six different marks")
    func marksAreDistinct() {
        let marks = Self.all.map(\.symbolName)
        #expect(Set(marks).count == marks.count)
        #expect(!marks.contains(""))
    }

    @Test("the states a live branch shows are all solid marks")
    func liveStatesAreFilled() {
        #expect(CheckState.running.isFilledMark)
        #expect(CheckState.passed.isFilledMark)
        #expect(CheckState.failed.isFilledMark)
        #expect(!CheckState.queued.isFilledMark)
    }
}
