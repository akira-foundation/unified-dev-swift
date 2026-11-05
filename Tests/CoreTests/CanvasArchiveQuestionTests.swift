import Foundation
import Testing
@testable import Core

@Suite("CanvasArchiveQuestion")
struct CanvasArchiveQuestionTests {
    private let fixture = CanvasSessionFixture()
    private let path = "/work/deck.udcanvas"

    private func opened() throws -> CanvasDocumentKeeper {
        CanvasDocumentKeeper(opening: .read(try CanvasDocumentCodec.encode(fixture.session().document)))
    }

    private func edit(_ keeper: inout CanvasDocumentKeeper) {
        _ = keeper.apply([fixture.move(fixture.boxID, revision: nil)], by: .owner)
    }

    private func read(_ keeper: inout CanvasDocumentKeeper, disk: Data?) {
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(disk))
    }

    private func question(_ keeper: CanvasDocumentKeeper) -> CanvasArchiveQuestion? {
        CanvasArchiveQuestion(
            stranded: keeper.hasStrandedEdits ? [path] : [],
            copiesOfOwnerWork: keeper.copiesHoldingOwnerWork
        )
    }

    @Test func aVanishedFileWithAnEditAsks() throws {
        var keeper = try opened()
        read(&keeper, disk: nil)
        edit(&keeper)
        #expect(keeper.nextStep() == nil)

        let asked = try #require(question(keeper))

        #expect(asked.losses == ["the canvas edits in deck.udcanvas, which have not reached the file"])
    }

    @Test func aFailedWriteAsks() throws {
        var keeper = try opened()
        edit(&keeper)
        #expect(keeper.nextStep() != nil)
        keeper.finish(.writeFailed("disk full"))

        #expect(question(keeper)?.losses.first?.contains("deck.udcanvas") == true)
    }

    @Test func aRefusedFileWithAnEditAsks() throws {
        var keeper = try opened()
        read(&keeper, disk: Data("{ not json".utf8))
        edit(&keeper)

        #expect(question(keeper) != nil)
    }

    @Test func aHeldCopyAsks() throws {
        var keeper = try opened()
        edit(&keeper)
        guard case .save(let data, _) = keeper.nextStep() else {
            Issue.record("expected a save")
            return
        }
        keeper.finish(.written(data))
        var outside = fixture.session().document
        outside.frames[0].name = "C1"
        read(&keeper, disk: try CanvasDocumentCodec.encode(outside))
        #expect(keeper.nextStep() != nil)
        keeper.finish(.backedUp("/work/deck.backup-1.udcanvas"))

        let asked = try #require(question(keeper))

        #expect(asked.losses == ["your canvas edits, which are only in the copy deck.backup-1.udcanvas beside the canvas"])
    }

    @Test func nothingStrandedDoesNotAsk() throws {
        var keeper = try opened()
        edit(&keeper)
        guard case .save(let data, _) = keeper.nextStep() else {
            Issue.record("expected a save")
            return
        }
        keeper.finish(.written(data))

        #expect(question(keeper) == nil)
    }

    @Test func acknowledgedLossesAreNotAskedAgain() {
        #expect(!CanvasArchiveQuestion.asks(["a"], acknowledged: ["a", "b"]))
    }

    @Test func aLossNotYetAcknowledgedAsks() {
        #expect(CanvasArchiveQuestion.asks(["a", "c"], acknowledged: ["a", "b"]))
    }

    @Test func aCanvasLossMakesTheArchiveRequestDestructive() {
        let loss = "the canvas edits in deck.udcanvas, which have not reached the file"
        let request = ArchiveRequest(
            workspace: Workspace(repoID: .new(), name: "Deck", branch: "deck", path: "/tmp/deck", baseBranch: "main"),
            report: WorkspaceSafetyReport(),
            hazards: ArchiveHazards(isAgentMidTurn: true, canvasLosses: [loss])
        )

        #expect(request.isDestructive)
        #expect(request.losses.last == loss)
        #expect(request.message.contains("This would lose:\n\u{2022} the turn an agent"))
        #expect(request.confirmLabel == "Archive and lose that work")
    }

    @Test func theRefusalNamesTheLossesAndTheWayBack() throws {
        let asked = try #require(CanvasArchiveQuestion(stranded: [path], copiesOfOwnerWork: []))

        #expect(asked.refusal.contains("\u{2022} the canvas edits in deck.udcanvas"))
        #expect(asked.refusal.contains("remove the project again"))
    }
}
