import Foundation
import Testing
@testable import Core

@MainActor
private final class ResolveBench {
    var keeper: CanvasDocumentKeeper
    var handover: CanvasCommentHandover?
    var disk: CanvasDiskOutcome?
    var orders: [CanvasCommentResolveOrder] = []

    init(_ document: CanvasDocument, handover: CanvasCommentHandover?) throws {
        keeper = CanvasDocumentKeeper(opening: .read(try CanvasDocumentCodec.encode(document)))
        self.handover = handover
    }

    var comments: [CanvasComment] {
        if case .document(let document) = keeper.document { return document.comments }
        return []
    }

    func resolve(_ order: CanvasCommentResolveOrder) -> CanvasCommentResolveOutcome {
        orders.append(order)
        switch CanvasCommentResolve.begin(order, handover: handover, on: &keeper) {
        case .refused(let sentence):
            return .refused(sentence)
        case .pending(let pending):
            return .resolved(disk.map { CanvasCommentResolveResult(state: pending.state, disk: $0) }
                ?? CanvasCommentResolve.conclude(pending, on: keeper))
        }
    }
}

@MainActor
@Suite("Resolving a canvas comment", .scratchDirectory)
struct CanvasCommentResolveToolTests {
    private let fixture = CanvasSessionFixture()
    private let caller = SessionID("caller")
    private let linked = DeliveryID("d1")

    private var identity: BridgeIdentity {
        BridgeIdentity(sessionID: caller, workspaceID: WorkspaceID("w"), role: .workspace)
    }

    private func bench(
        _ state: CanvasComment.State = .working, delivery: DeliveryID? = DeliveryID("d1"), handedTo: SessionID? = SessionID("caller")
    ) throws -> ResolveBench {
        var document = fixture.session().document
        document.comments = [CanvasComment(
            id: CanvasCommentID("c1"), anchor: CanvasPoint(x: 1, y: 2), text: "Bigger", state: state, deliveryID: delivery,
            createdAt: Date(timeIntervalSince1970: 0)
        )]
        return try ResolveBench(document, handover: delivery.map { CanvasCommentHandover(delivery: $0, target: handedTo) })
    }

    private func tool(_ bench: ResolveBench) -> CanvasCommentResolveTool {
        CanvasCommentResolveTool { order, workspaceID in
            #expect(workspaceID == WorkspaceID("w"))
            return bench.resolve(order)
        }
    }

    private func request(
        comment: String = "c1", outcome: String = "resolved", response: String = "Made it bigger."
    ) -> MCPRequest {
        MCPRequest(id: .integer(1), method: CanvasCommentResolveToolName.resolve, params: .object([
            "path": .string(" c.udcanvas "), "commentID": .string(comment),
            "outcome": .string(outcome), "response": .string(response),
        ]))
    }

    private func answer(_ result: BridgeToolResult) throws -> [String: JSONValue] {
        guard case .object(let fields)? = JSONValue.parse(Data(result.text.utf8)) else {
            Issue.record("not an object: \(result.text)")
            return [:]
        }
        return fields
    }

    private func call(_ bench: ResolveBench, _ request: MCPRequest, label: String) async throws -> BridgeToolResult {
        await tool(bench).call(request, as: identity, store: try makeTestStore(label))
    }

    @Test func resolveMarksDoneWithResponse() async throws {
        let bench = try bench()
        let result = try await call(bench, request(), label: "resolve-done")

        #expect(!result.isError)
        let fields = try answer(result)
        #expect(fields["resolved"] == .bool(true))
        #expect(fields["state"] == .string("resolved"))
        #expect(fields["saved"] == .bool(true))
        #expect(bench.comments.first?.state == .resolved)
        #expect(bench.comments.first?.response == "Made it bigger.")
        #expect(bench.orders.first?.path == "c.udcanvas")
        #expect(bench.orders.first?.caller == caller)
    }

    @Test func resolveDeclinesWithReason() async throws {
        let bench = try bench()
        let result = try await call(bench, request(outcome: "declined", response: "It would overflow."), label: "resolve-declined")

        #expect(!result.isError)
        #expect(try answer(result)["state"] == .string("declined"))
        #expect(bench.comments.first?.state == .declined)
        #expect(bench.comments.first?.response == "It would overflow.")
    }

    @Test(arguments: ["", "  \n "])
    func resolveNeedsAResponse(response: String) async throws {
        let bench = try bench()
        let result = try await call(bench, request(response: response), label: "resolve-blank")

        #expect(result.isError)
        #expect(result.text.contains("response"))
        #expect(bench.orders.isEmpty)
        #expect(bench.comments.first?.state == .working)
    }

    @Test func resolveUnknownCommentIsRefused() async throws {
        let bench = try bench()
        let result = try await call(bench, request(comment: "nope"), label: "resolve-unknown")

        #expect(result.isError)
        #expect(result.text.contains("no comment 'nope'"))
        #expect(bench.comments.first?.state == .working)
    }

    @Test(arguments: ["done", "working", ""])
    func anOutcomeOtherThanTheTwoIsRefused(outcome: String) async throws {
        let bench = try bench()
        let result = try await call(bench, request(outcome: outcome), label: "resolve-outcome")

        #expect(result.isError)
        #expect(bench.orders.isEmpty)
    }

    @Test func aMissingPathOrCommentIsRefused() async throws {
        let bench = try bench()
        let noPath = MCPRequest(id: .integer(1), method: "x", params: .object([
            "commentID": .string("c1"), "outcome": .string("resolved"), "response": .string("Done"),
        ]))
        let noComment = MCPRequest(id: .integer(1), method: "x", params: .object([
            "path": .string("c.udcanvas"), "outcome": .string("resolved"), "response": .string("Done"),
        ]))
        let first = try await call(bench, noPath, label: "resolve-no-path")
        let second = try await call(bench, noComment, label: "resolve-no-comment")

        #expect(first.isError)
        #expect(second.isError)
        #expect(bench.orders.isEmpty)
    }

    @Test func aConnectionSpeakingForNoWorkspaceIsRefused() async throws {
        let bench = try bench()
        let result = await tool(bench).call(request(), as: .owner, store: try makeTestStore("resolve-owner"))

        #expect(result.isError)
        #expect(bench.orders.isEmpty)
    }

    @Test func aChatThatWasNotHandedTheCommentIsRefusedAndNothingChanges() async throws {
        let bench = try bench(handedTo: SessionID("another"))
        let result = try await call(bench, request(), label: "resolve-other-chat")

        #expect(result.isError)
        #expect(result.text.contains("another chat"))
        #expect(bench.comments.first?.state == .working)
        #expect(bench.comments.first?.response == nil)
    }

    @Test func aCommentNoChatWasHandedIsRefused() async throws {
        let bench = try bench(.queued, delivery: nil)
        let result = try await call(bench, request(), label: "resolve-no-chat")

        #expect(result.isError)
        #expect(result.text.contains("not been sent"))
        #expect(bench.comments.first?.state == .queued)
    }

    @Test func aCommentWhoseRowIsGoneIsRefusedAndTheOwnerCanResendIt() async throws {
        let bench = try bench(.unanswered, handedTo: nil)
        let result = try await call(bench, request(), label: "resolve-row-gone")

        #expect(result.isError)
        #expect(result.text.contains("send it again"))
        #expect(bench.comments.first?.state == .unanswered)
    }

    @Test func aCommentSentAgainWhileThisWasCheckedIsRefused() async throws {
        let bench = try bench()
        bench.handover = CanvasCommentHandover(delivery: DeliveryID("old"), target: caller)
        let result = try await call(bench, request(), label: "resolve-stale")

        #expect(result.isError)
        #expect(bench.comments.first?.state == .working)
    }

    @Test func aCommentStillInTheQueueIsNotAnsweredBeforeItIsSent() async throws {
        let bench = try bench(.queued)
        let result = try await call(bench, request(), label: "resolve-queued")

        #expect(result.isError)
        #expect(result.text.contains("has not been sent"))
        #expect(bench.comments.first?.state == .queued)
        #expect(bench.comments.first?.response == nil)
    }

    @Test(arguments: [CanvasComment.State.working, .unanswered])
    func theChatItWasHandedToCanAnswerItInAnOpenState(state: CanvasComment.State) async throws {
        let bench = try bench(state)
        let result = try await call(bench, request(), label: "resolve-open")

        #expect(!result.isError)
        #expect(bench.comments.first?.state == .resolved)
    }

    @Test func aCommentAlreadyAnsweredIsRefusedAndKeepsItsAnswer() async throws {
        let bench = try bench(.declined)
        let result = try await call(bench, request(), label: "resolve-twice")

        #expect(result.isError)
        #expect(result.text.contains("already declined"))
        #expect(bench.comments.first?.state == .declined)
    }

    @Test func aDocumentUnderAHoldRefusesTheResolve() async throws {
        let bench = try bench()
        bench.keeper.perform(.reload)
        let step = bench.keeper.nextStep()
        #expect(step == .read)
        bench.keeper.finish(.read(nil))
        let result = try await call(bench, request(), label: "resolve-hold")

        #expect(result.isError)
        #expect(result.text.contains("no longer on disk"))
        #expect(bench.comments.first?.state == .working)
    }

    @Test func aResolveAsksForTheDocumentToBeSaved() throws {
        let bench = try bench()
        _ = bench.resolve(CanvasCommentResolveOrder(
            path: "c.udcanvas", commentID: CanvasCommentID("c1"), state: .resolved, response: "Done", caller: caller
        ))
        guard case .save(let bytes, _) = bench.keeper.nextStep(),
              case .document(let written) = CanvasDocumentCodec.decode(bytes) else {
            Issue.record("expected a save")
            return
        }
        #expect(written.comments.first?.state == .resolved)
    }

    @Test func aSaveThatFailedIsReported() async throws {
        let bench = try bench()
        bench.disk = .notSaved("Saving failed")
        let result = try await call(bench, request(), label: "resolve-unsaved")

        #expect(!result.isError)
        let fields = try answer(result)
        #expect(fields["resolved"] == .bool(true))
        #expect(fields["saved"] == .bool(false))
        #expect(fields["warning"]?.stringValue?.contains("Saving failed") == true)
    }

    @Test func aFileReplacedWhileSavingIsReportedAsNotResolved() async throws {
        let bench = try bench()
        bench.disk = .replaced
        let result = try await call(bench, request(), label: "resolve-replaced")

        #expect(result.isError)
        let fields = try answer(result)
        #expect(fields["resolved"] == .bool(false))
        #expect(fields["saved"] == .bool(false))
    }

    @Test func concludingReadsWhatTheKeeperKnowsAboutTheDisk() throws {
        let bench = try bench()
        let start = CanvasCommentResolve.begin(
            CanvasCommentResolveOrder(path: "c", commentID: CanvasCommentID("c1"), state: .resolved, response: "Done", caller: caller),
            handover: bench.handover, on: &bench.keeper
        )
        guard case .pending(let pending) = start else {
            Issue.record("expected it to go ahead: \(start)")
            return
        }
        #expect(CanvasCommentResolve.conclude(pending, on: bench.keeper).disk == .saved)

        bench.keeper.perform(.reload)
        while bench.keeper.nextStep() != nil { bench.keeper.finish(.read(nil)) }
        #expect(bench.keeper.warning == .vanished)
        if case .notSaved = CanvasCommentResolve.conclude(pending, on: bench.keeper).disk {} else {
            Issue.record("a hold after the resolve means it is not on disk")
        }
    }

    @Test func aResolveIsNotAnUndoStepAndAnUndoLeavesItAlone() throws {
        let bench = try bench()
        _ = bench.keeper.apply([fixture.move(fixture.boxID, revision: nil)], by: .owner)
        let depth = bench.keeper.recordedSteps
        _ = bench.resolve(CanvasCommentResolveOrder(
            path: "c", commentID: CanvasCommentID("c1"), state: .resolved, response: "Done", caller: caller
        ))
        #expect(bench.keeper.recordedSteps == depth)

        let undone = bench.keeper.undo()
        #expect(undone)
        #expect(bench.comments.first?.state == .resolved)
        #expect(bench.comments.first?.response == "Done")
        let redone = bench.keeper.redo()
        #expect(redone)
        #expect(bench.comments.first?.state == .resolved)
    }

    @Test func aCommentLeftAfterAnEditSurvivesUndoingThatEdit() throws {
        let bench = try bench()
        _ = bench.keeper.apply([fixture.move(fixture.boxID, revision: nil)], by: .owner)
        let new = CanvasComment(anchor: CanvasPoint(x: 3, y: 3), text: "After", createdAt: Date(timeIntervalSince1970: 1))
        bench.keeper.changeComments { document in
            var changed = document
            changed.comments.append(new)
            return changed
        }
        let undone = bench.keeper.undo()
        #expect(undone)
        #expect(bench.comments.contains { $0.id == new.id })
    }

    @Test func anOrchestratorMayAnswerAComment() async throws {
        let store = try makeTestStore("resolve-orchestrator")
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let lead = try await store.upsert(Workspace(
            repoID: repo.id, name: "lead", branch: "b/lead", path: TestScratch.unique("lead"), baseBranch: "main"
        ))
        try await store.setOrchestrator(true, workspaceID: lead.id)
        let chat = BridgeIdentity(sessionID: caller, workspaceID: lead.id, role: .workspace)
        let bench = try bench()
        let tool = CanvasCommentResolveTool { order, _ in bench.resolve(order) }

        let result = await tool.call(request(outcome: "declined", response: "I cannot edit here."), as: chat, store: store)

        #expect(!result.isError)
        #expect(bench.comments.first?.state == .declined)
        let name = BridgeToolApproval.toolPrefix + CanvasCommentResolveToolName.resolve
        #expect(OrchestratorToolGuard.refusal(toolName: name, input: .object([:])) == nil)
    }

    @Test func theToolAnswersForItselfAndIsDecidedByName() {
        #expect(BridgeToolApproval.selfApproved.contains(CanvasCommentResolveToolName.resolve))
        #expect(CanvasCommentResolveTool { _, _ in .refused("x") }.roles == BridgeWorkspaceScope.roles)
    }
}
