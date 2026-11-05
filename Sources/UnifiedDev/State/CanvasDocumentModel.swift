import Foundation
import ImageIO
import Observation
import Core

@MainActor
@Observable
final class CanvasDocumentModel: CanvasKeeperHolding {
    let path: String
    let worktree: String

    private(set) var document: CanvasDocumentDecoding
    private(set) var warning: CanvasDiskWarning?
    private(set) var editing: CanvasTextEditing?
    var exportNotice: CanvasExportNotice?
    private(set) var confirmedCommentDeliveries: Set<DeliveryID> = []
    var commentsAddedThisRun = CanvasCommentsAddedThisRun()

    @ObservationIgnored let undoManager = UndoManager()
    @ObservationIgnored let pendingCommits = CanvasPendingCommits()
    @ObservationIgnored var onCommentsNeedSettling: (@MainActor () -> Void)?
    @ObservationIgnored var onHoldLifted: (@MainActor () -> Void)?
    @ObservationIgnored var commentCourier: CanvasCommentCourier?
    @ObservationIgnored var keeper: CanvasDocumentKeeper
    @ObservationIgnored private let worker: CanvasDiskWorker
    @ObservationIgnored private var draining: Task<Void, Never>?
    @ObservationIgnored private var registeredSteps = 0
    @ObservationIgnored private var seenHoldsLifted = 0

    init(path: String, worktree: String) {
        self.path = path
        self.worktree = worktree
        var keeper = CanvasDocumentKeeper(opening: CanvasDiskWorker.read(path))
        keeper.changeComments(CanvasCommentFlow.afterRestart)
        self.keeper = keeper
        document = keeper.document
        warning = keeper.warning
        worker = CanvasDiskWorker(path: path)
        undoManager.groupsByEvent = false
        undoManager.levelsOfUndo = CanvasHistory.limit
    }

    func reconcile() async {
        await requestReconcile().value
    }

    @discardableResult
    func requestReconcile() -> Task<Void, Never> {
        keeper.perform(.reload)
        return drain()
    }

    func changeComments(_ change: (CanvasDocument) -> CanvasDocument) {
        keeper.changeComments(change)
        publish()
        drain()
    }

    func settleOpening() {
        drain()
        onCommentsNeedSettling?()
    }

    func confirmCommentDeliveries(_ live: Set<DeliveryID>) {
        confirmedCommentDeliveries = live
    }

    func confirmCommentDelivery(_ id: DeliveryID) {
        confirmedCommentDeliveries.insert(id)
    }

    func resolveComment(
        _ order: CanvasCommentResolveOrder, handover: CanvasCommentHandover?
    ) async -> CanvasCommentResolveOutcome {
        switch CanvasCommentResolve.begin(order, handover: handover, on: &keeper) {
        case .refused(let sentence):
            return .refused(sentence)
        case .pending(let pending):
            publish()
            drain()
            await settle()
            return .resolved(CanvasCommentResolve.conclude(pending, on: keeper))
        }
    }

    func perform(_ action: CanvasDiskWarningAction) {
        keeper.perform(action)
        publish()
        drain()
    }

    var hasStrandedEdits: Bool { keeper.hasStrandedEdits }
    var copiesHoldingOwnerWork: [String] { keeper.copiesHoldingOwnerWork }

    func flush() async {
        finishEditing()
        if case .saveFailed = warning { keeper.perform(.tryAgain) }
        await drain().value
    }

    @discardableResult
    func apply(_ operations: [CanvasOperation], by author: CanvasAuthor = .owner) -> CanvasEditOutcome? {
        guard let outcome = keeper.apply(operations, by: author) else { return nil }
        switch outcome {
        case .applied: break
        case .conflict(let conflicts): Log.canvas.error("canvas edit conflicted on \(conflicts.map(\.target), privacy: .public)")
        case .invalid(let reason): Log.canvas.error("canvas edit refused: \(reason, privacy: .public)")
        }
        publish()
        drain()
        return outcome
    }

    func applyAsAgent(_ operations: [CanvasOperation]) async -> CanvasAgentEditOutcome {
        switch CanvasAgentEdit.begin(operations, flushing: pendingCommits, in: self) {
        case .refused(let sentence):
            return .refused(sentence)
        case .conflict(let conflicts):
            Log.canvas.error("canvas edit conflicted on \(conflicts.map(\.target), privacy: .public)")
            publish()
            return .conflict(conflicts)
        case .pending(let pending):
            publish()
            drain()
            await settle()
            return .applied(CanvasAgentEdit.conclude(pending, on: keeper))
        }
    }

    func update(_ build: (CanvasDocument) -> [CanvasOperation]) {
        guard case .document(let current) = keeper.document else { return }
        let operations = build(current)
        if !operations.isEmpty { apply(operations) }
    }

    func startEditing(_ element: CanvasElementID, text: CanvasText) {
        finishEditing()
        keeper.beginEditing(element)
        editing = CanvasTextEditing(elementID: element, text: text)
        syncDraft()
        publish()
    }

    func finishEditing() {
        pendingCommits.flush()
        guard editing != nil else { return }
        syncDraft()
        keeper.finishDraft()
        editing = nil
        publish()
        drain()
    }

    private func syncDraft() {
        guard let editing, case .document(let current) = keeper.document,
              let element = current.elements.first(where: { $0.id == editing.elementID }) else { return }
        let padding = CanvasEditing.notePadding(of: element)
        let measured = CanvasTextMeasure.size(of: editing.text, width: element.rect.size.width - padding, padding: padding)
        keeper.setDraft(CanvasTextDraft(
            elementID: editing.elementID, original: editing.original, text: editing.text, measuredHeight: measured.height
        ))
    }

    private func registerStep(_ action: @escaping @MainActor (CanvasDocumentModel) -> Void) {
        undoManager.beginUndoGrouping()
        undoManager.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated { action(model) }
        }
        undoManager.setActionName("Canvas Edit")
        undoManager.endUndoGrouping()
    }

    private func undoStep() {
        syncDraft()
        guard keeper.undo() else { return }
        registerStep { $0.redoStep() }
        publish()
        drain()
    }

    private func redoStep() {
        syncDraft()
        guard keeper.redo() else { return }
        registerStep { $0.undoStep() }
        publish()
        drain()
    }

    func settle() async {
        await draining?.value
    }

    @discardableResult
    private func drain() -> Task<Void, Never> {
        if let draining { return draining }
        let task = Task { [self] in
            while let step = nextStep() {
                let result = await worker.perform(step)
                syncDraft()
                let reloads = keeper.reloads
                let wasUnreadable = !isReadable(keeper.document)
                keeper.finish(result)
                if keeper.reloads != reloads {
                    undoManager.removeAllActions()
                    registeredSteps = keeper.recordedSteps
                }
                publish()
                if keeper.reloads != reloads || (wasUnreadable && isReadable(keeper.document)) {
                    onCommentsNeedSettling?()
                }
            }
            publish()
            draining = nil
        }
        draining = task
        return task
    }

    private func isReadable(_ decoding: CanvasDocumentDecoding) -> Bool {
        if case .document = decoding { return true }
        return false
    }

    private func nextStep() -> CanvasDiskStep? {
        syncDraft()
        return keeper.nextStep()
    }

    private func publish() {
        while registeredSteps < keeper.recordedSteps {
            registeredSteps += 1
            registerStep { $0.undoStep() }
        }
        let latest = keeper.document
        if latest != document { document = latest }
        if keeper.warning != warning { warning = keeper.warning }
        if keeper.holdsLifted != seenHoldsLifted {
            seenHoldsLifted = keeper.holdsLifted
            onHoldLifted?()
        }
        if keeper.draft == nil, editing != nil { editing = nil }
    }

    func addImage(from source: URL, in frameID: CanvasFrameID) async {
        let documentPath = path
        let imported = await Task.detached { () -> (path: String, size: CanvasSize)? in
            guard let relative = try? CanvasImageImport.copy(source.path, beside: documentPath) else { return nil }
            return (relative, Self.pixelSize(of: source))
        }.value
        guard let imported,
              case .document(let current) = keeper.document,
              let frame = current.frames.first(where: { $0.id == frameID }) else {
            Log.canvas.error("canvas image import failed for \(source.lastPathComponent, privacy: .public)")
            return
        }
        let size = CanvasImageImport.fittedSize(of: imported.size, in: frame.rect.size)
        let rect = CanvasRect(
            x: (frame.rect.size.width - size.width) / 2,
            y: (frame.rect.size.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
        apply([.addElement(CanvasElement(frameID: frameID, rect: rect, kind: .image(path: imported.path)))])
    }

    nonisolated private static func pixelSize(of url: URL) -> CanvasSize {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Double,
              let height = properties[kCGImagePropertyPixelHeight] as? Double else {
            return CanvasSize(width: 0, height: 0)
        }
        return CanvasSize(width: width, height: height)
    }
}
