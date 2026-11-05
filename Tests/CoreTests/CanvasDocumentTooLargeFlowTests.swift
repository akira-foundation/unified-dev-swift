import Foundation
import Testing
@testable import Core

@Suite("What a canvas too large to save tells the agent and the owner", .serialized)
struct CanvasDocumentTooLargeFlowTests {
    private let oversize = CanvasOversizeFixture()
    private let notSaved = CanvasDiskOutcome.notSaved("This canvas is too large to save")

    private func opened(at path: String) throws -> CanvasDocumentKeeper {
        _ = try oversize.nearlyFull(path)
        return CanvasDocumentKeeper(opening: CanvasDiskWorker.read(path))
    }

    private func pending(_ start: CanvasAgentEditStart) throws -> CanvasPendingAgentEdit {
        guard case .pending(let pending) = start else { throw CocoaError(.featureUnsupported) }
        return pending
    }

    @Test func theEditThatFirstCrossesTheLimitIsNotSaved() throws {
        let directory = try oversize.scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        var keeper = try opened(at: directory + "/full.udcanvas")

        let edit = try pending(CanvasAgentEdit.begin([.addElement(oversize.text("more", bytes: 2_000_000))], on: &keeper))
        #expect(keeper.nextStep() == nil)

        #expect(CanvasAgentEdit.conclude(edit, on: keeper).disk == notSaved)
    }

    @Test func anEditAlreadyInThatStateIsNotSaved() throws {
        let directory = try oversize.scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        var keeper = try opened(at: directory + "/full.udcanvas")
        oversize.overfill(&keeper)
        #expect(keeper.nextStep() == nil)

        let edit = try pending(CanvasAgentEdit.begin([.addElement(oversize.text("small", bytes: 4))], on: &keeper))
        #expect(keeper.nextStep() == nil)

        #expect(CanvasAgentEdit.conclude(edit, on: keeper).disk == notSaved)
    }

    @Test func aResolveInThatStateIsNotSaved() throws {
        let directory = try oversize.scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        var keeper = try opened(at: directory + "/full.udcanvas")
        oversize.overfill(&keeper)
        #expect(keeper.nextStep() == nil)

        let resolve = CanvasPendingCommentResolve(state: .resolved, reloadsBefore: keeper.reloads)

        #expect(CanvasCommentResolve.conclude(resolve, on: keeper).disk == notSaved)
    }

    private func stranded(at path: String, worker: CanvasDiskWorker) async throws -> (keeper: CanvasDocumentKeeper, outside: Data) {
        var keeper = try opened(at: path)
        oversize.overfill(&keeper)
        await oversize.run(&keeper, on: worker)
        let outside = try CanvasDocumentCodec.encode(CanvasDocument(elements: [oversize.text("theirs", bytes: 4)]))
        try outside.write(to: URL(filePath: path))
        keeper.finish(CanvasDiskWorker.read(path))
        await oversize.run(&keeper, on: worker)
        return (keeper, outside)
    }

    @Test func theWarningSaysWhatRemovingSomethingWillDoOnceTheFileChanged() {
        let warning = CanvasDiskWarning.tooLargeToKeepCopy(82_001_204)
        #expect(warning.message.contains("79 MB") && warning.message.contains("64 MB"))
        #expect(warning.message.contains("only there"))
        #expect(warning.message.contains("copy beside the file") && warning.message.contains("reload"))
        #expect(!warning.message.contains("will save"))
        #expect(warning.actions.isEmpty && !warning.refusesAgentEdits)
    }

    @Test func anAgentEditWhileTheFileChangedIsNotSavedEither() async throws {
        let directory = try oversize.scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let path = directory + "/full.udcanvas"
        var keeper = try await stranded(at: path, worker: CanvasDiskWorker(path: path)).keeper
        let edit = try pending(CanvasAgentEdit.begin([.addElement(oversize.text("small", bytes: 4))], on: &keeper))
        #expect(keeper.nextStep() == nil)
        guard case .notSaved = CanvasAgentEdit.conclude(edit, on: keeper).disk else {
            Issue.record("expected the edit not to be reported as saved")
            return
        }
    }

    @Test func anotherEditThatIsStillTooLargeKeepsSayingTheFileChanged() async throws {
        let directory = try oversize.scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let path = directory + "/full.udcanvas"
        let worker = CanvasDiskWorker(path: path)
        var keeper = try await stranded(at: path, worker: worker).keeper

        _ = keeper.apply([.addElement(oversize.text("small", bytes: 4))], by: .owner)
        await oversize.run(&keeper, on: worker)

        guard case .tooLargeToKeepCopy = keeper.warning else {
            Issue.record("got \(String(describing: keeper.warning))")
            return
        }
    }

    @Test func theSameBytesAreNotWeighedAgainOnTheNextReconcile() async throws {
        let directory = try oversize.scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let path = directory + "/full.udcanvas"
        let worker = CanvasDiskWorker(path: path)
        var keeper = try await stranded(at: path, worker: worker).keeper
        let decisions = keeper.reconcileDecisions

        keeper.perform(.reload)
        await oversize.run(&keeper, on: worker)
        keeper.perform(.reload)
        await oversize.run(&keeper, on: worker)

        #expect(keeper.reconcileDecisions == decisions)
        guard case .tooLargeToKeepCopy = keeper.warning else {
            Issue.record("got \(String(describing: keeper.warning))")
            return
        }
    }

    @Test func differentBytesAreWeighedAgain() async throws {
        let directory = try oversize.scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let path = directory + "/full.udcanvas"
        let worker = CanvasDiskWorker(path: path)
        var keeper = try await stranded(at: path, worker: worker).keeper
        let decisions = keeper.reconcileDecisions

        try CanvasDocumentCodec.encode(CanvasDocument(elements: [oversize.text("again", bytes: 4)])).write(to: URL(filePath: path))
        keeper.perform(.reload)
        await oversize.run(&keeper, on: worker)

        #expect(keeper.reconcileDecisions == decisions + 1)
    }

    @Test func theFileGoingBackToWhatWeLastWroteSaysTheOrdinaryWarningAgain() async throws {
        let directory = try oversize.scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let path = directory + "/full.udcanvas"
        let original = try oversize.nearlyFull(path)
        let worker = CanvasDiskWorker(path: path)
        var keeper = try await stranded(at: path, worker: worker).keeper

        try original.write(to: URL(filePath: path))
        keeper.perform(.reload)
        await oversize.run(&keeper, on: worker)

        guard case .tooLargeToSave = keeper.warning else {
            Issue.record("got \(String(describing: keeper.warning))")
            return
        }
    }

    @Test func reducingAfterTheFileChangedKeepsACopyAndReloads() async throws {
        let directory = try oversize.scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let path = directory + "/full.udcanvas"
        let worker = CanvasDiskWorker(path: path)
        let made = try await stranded(at: path, worker: worker)
        var keeper = made.keeper

        oversize.removeTheBulk(&keeper)
        await oversize.run(&keeper, on: worker)

        #expect(try oversize.held(keeper).elements.map(\.id) == [CanvasElementID("theirs")])
        #expect(try Data(contentsOf: URL(filePath: path)) == made.outside)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory).count == 2)
    }

    private func refusedSaveOver(at path: String, worker: CanvasDiskWorker) async throws -> CanvasDocumentKeeper {
        try CanvasDocumentFile.write(CanvasDocument(elements: [oversize.text("mine", bytes: 4)]), to: path)
        var keeper = CanvasDocumentKeeper(opening: CanvasDiskWorker.read(path))
        try oversize.grow(path)
        keeper.finish(CanvasDiskWorker.read(path))
        keeper.perform(.saveOver)
        await oversize.run(&keeper, on: worker)
        return keeper
    }

    @Test func theNextReconcileKeepsTheAdviceAboutTheLargeFile() async throws {
        let directory = try oversize.scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let path = directory + "/deck.udcanvas"
        let worker = CanvasDiskWorker(path: path)
        var keeper = try await refusedSaveOver(at: path, worker: worker)
        #expect(keeper.warning == .fileTooLarge(oversize.limit + 1))

        keeper.perform(.reload)
        await oversize.run(&keeper, on: worker)
        #expect(keeper.warning == .fileTooLarge(oversize.limit + 1))

        try oversize.grow(path, by: 9)
        keeper.perform(.reload)
        await oversize.run(&keeper, on: worker)
        #expect(keeper.warning == .fileTooLarge(oversize.limit + 9))
    }

    @Test func aDifferentReadFailureReplacesTheAdvice() async throws {
        let directory = try oversize.scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let path = directory + "/deck.udcanvas"
        var keeper = try await refusedSaveOver(at: path, worker: CanvasDiskWorker(path: path))

        keeper.finish(.unreadable("permission denied"))

        guard case .refused(let reason) = keeper.warning else {
            Issue.record("got \(String(describing: keeper.warning))")
            return
        }
        #expect(reason.contains("permission denied"))
    }

    @Test func aFileTooLargeBeforeAnyAdviceIsStillAReadRefusal() async throws {
        let directory = try oversize.scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let path = directory + "/deck.udcanvas"
        try CanvasDocumentFile.write(CanvasDocument(elements: [oversize.text("mine", bytes: 4)]), to: path)
        var keeper = CanvasDocumentKeeper(opening: CanvasDiskWorker.read(path))
        try oversize.grow(path)

        keeper.finish(CanvasDiskWorker.read(path))

        guard case .refused(let reason) = keeper.warning else {
            Issue.record("got \(String(describing: keeper.warning))")
            return
        }
        #expect(reason.contains("65 MB") && reason.contains("64 MB"))
    }
}
