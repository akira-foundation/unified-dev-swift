import Foundation
import Testing
@testable import Core

@Suite("What Archive anyway means")
struct ArchiveDecisionGateTests {
    private func request(checking: Bool, agentMidTurn: Bool = false) -> ArchiveRequest {
        let workspace = Workspace(
            repoID: RepoID.new(), name: "Lighthouse", branch: "lighthouse",
            path: "/tmp/Lighthouse", baseBranch: "main"
        )
        let hazards = ArchiveHazards(isAgentMidTurn: agentMidTurn)
        return checking
            ? ArchiveRequest.checking(workspace: workspace, hazards: hazards)
            : ArchiveRequest(workspace: workspace, report: WorkspaceSafetyReport(), hazards: hazards)
    }

    private let risky = WorkspaceSafetyReport(hasUncommittedChanges: true)

    @Test("pressed while checking, the archive happens with no second question")
    func anywayDoesNotAskAgain() {
        let decision = ArchiveDecisionGate.resolve(
            pressedWhileChecking: true, request: request(checking: true),
            report: risky, isAgentMidTurn: false
        )

        #expect(decision == .archive)
    }

    @Test("pressed after the report, a report that puts more at risk asks again, as it does today")
    func afterTheReportItStillAsks() {
        let decision = ArchiveDecisionGate.resolve(
            pressedWhileChecking: false, request: request(checking: false),
            report: risky, isAgentMidTurn: false
        )

        guard case .ask(let again) = decision else {
            Issue.record("a riskier report did not ask again")
            return
        }
        #expect(again.isDestructive)
        #expect(!again.isChecking)
    }

    @Test(
        "an agent that started a turn while the popover was up is refused, checking or not",
        arguments: [true, false]
    )
    func anAgentMidTurnIsAlwaysRefused(whileChecking: Bool) {
        let decision = ArchiveDecisionGate.resolve(
            pressedWhileChecking: whileChecking, request: request(checking: whileChecking),
            report: WorkspaceSafetyReport(), isAgentMidTurn: true
        )

        guard case .refuse(let sentence) = decision else {
            Issue.record("an agent mid turn was not refused")
            return
        }
        #expect(sentence.contains("turn"))
    }

    @Test("a check that failed outright still archives when the press was anyway")
    func anywaySurvivesAFailedCheck() {
        let decision = ArchiveDecisionGate.resolve(
            pressedWhileChecking: true, request: request(checking: true),
            report: nil, isAgentMidTurn: false
        )

        #expect(decision == .archive)
    }

    @Test("a check that failed without an anyway asks, and says it could not check")
    func aFailedCheckAsks() {
        let decision = ArchiveDecisionGate.resolve(
            pressedWhileChecking: false, request: request(checking: false),
            report: nil, isAgentMidTurn: false
        )

        guard case .ask(let again) = decision else {
            Issue.record("a failed check did not ask")
            return
        }
        #expect(again.message.contains(ArchiveRequest.uncheckedOnConfirming))
    }

    @Test("a report with nothing new in it archives, anyway or not", arguments: [true, false])
    func aQuietReportArchives(whileChecking: Bool) {
        let decision = ArchiveDecisionGate.resolve(
            pressedWhileChecking: whileChecking, request: request(checking: whileChecking),
            report: WorkspaceSafetyReport(), isAgentMidTurn: false
        )

        #expect(decision == .archive)
    }

    @Test("the archive runs against the report that arrived, not the empty one the question carried")
    func theRealReportIsWhatArchives() {
        let checking = request(checking: true)

        #expect(checking.reportForArchiving(fresh: risky) == risky)
        #expect(checking.reportForArchiving(fresh: nil) == nil)
    }

    @Test("a question that already carried a report keeps it, and a failed check carries none")
    func afinishedQuestionKeepsItsOwnReport() {
        let finished = ArchiveRequest(
            workspace: request(checking: false).workspace, report: risky
        )
        let failed = ArchiveRequest(
            workspace: request(checking: false).workspace,
            report: WorkspaceSafetyReport(),
            problem: ArchiveRequest.uncheckedOnConfirming
        )

        #expect(finished.reportForArchiving(fresh: WorkspaceSafetyReport()) == risky)
        #expect(failed.reportForArchiving(fresh: risky) == nil)
    }

    @Test("an agent already named as a loss when the question was asked is not asked about twice")
    func anAgentAlreadyNamedIsNotRefusedAgain() {
        let decision = ArchiveDecisionGate.resolve(
            pressedWhileChecking: false, request: request(checking: false, agentMidTurn: true),
            report: WorkspaceSafetyReport(), isAgentMidTurn: true
        )

        #expect(decision == .archive)
    }
}
