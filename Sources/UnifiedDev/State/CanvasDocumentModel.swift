import Foundation
import ImageIO
import Observation
import Core

@MainActor
@Observable
final class CanvasDocumentModel {
    let path: String
    let worktree: String

    private(set) var document: CanvasDocumentDecoding
    private(set) var warning: CanvasDiskWarning?

    @ObservationIgnored private var keeper: CanvasDocumentKeeper
    @ObservationIgnored private let worker: CanvasDiskWorker
    @ObservationIgnored private var draining: Task<Void, Never>?
    @ObservationIgnored private weak var undoManager: UndoManager?

    init(path: String, worktree: String) {
        self.path = path
        self.worktree = worktree
        let keeper = CanvasDocumentKeeper(opening: CanvasDiskWorker.read(path))
        self.keeper = keeper
        document = keeper.document
        warning = keeper.warning
        worker = CanvasDiskWorker(path: path)
    }

    func reconcile() async {
        await requestReconcile().value
    }

    @discardableResult
    func requestReconcile() -> Task<Void, Never> {
        keeper.perform(.reload)
        return drain()
    }

    func perform(_ action: CanvasDiskWarningAction) {
        keeper.perform(action)
        publish()
        drain()
    }

    @discardableResult
    func apply(_ operations: [CanvasOperation], by author: CanvasAuthor = .owner) -> CanvasEditOutcome? {
        let steps = keeper.recordedSteps
        guard let outcome = keeper.apply(operations, by: author) else { return nil }
        switch outcome {
        case .applied: break
        case .conflict(let conflicts): Log.canvas.error("canvas edit conflicted on \(conflicts.map(\.target), privacy: .public)")
        case .invalid(let reason): Log.canvas.error("canvas edit refused: \(reason, privacy: .public)")
        }
        if keeper.recordedSteps != steps, let undoManager { registerUndo(on: undoManager) }
        publish()
        drain()
        return outcome
    }

    func update(_ build: (CanvasDocument) -> [CanvasOperation]) {
        guard case .document(let current) = keeper.document else { return }
        let operations = build(current)
        if !operations.isEmpty { apply(operations) }
    }

    func beginEditing(_ element: CanvasElementID) {
        keeper.beginEditing(element)
        publish()
    }

    func attachUndo(_ manager: UndoManager?) {
        guard manager !== undoManager else { return }
        undoManager?.removeAllActions(withTarget: self)
        undoManager = manager
        guard let manager else { return }
        let grouped = manager.groupsByEvent
        manager.groupsByEvent = false
        for _ in 0..<keeper.undoDepth {
            manager.beginUndoGrouping()
            registerUndo(on: manager)
            manager.endUndoGrouping()
        }
        manager.groupsByEvent = grouped
    }

    private func registerUndo(on manager: UndoManager) {
        manager.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated { model.undoStep() }
        }
        manager.setActionName("Canvas Edit")
    }

    private func registerRedo(on manager: UndoManager) {
        manager.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated { model.redoStep() }
        }
        manager.setActionName("Canvas Edit")
    }

    private func undoStep() {
        guard keeper.undo() else { return }
        if let undoManager { registerRedo(on: undoManager) }
        publish()
        drain()
    }

    private func redoStep() {
        guard keeper.redo() else { return }
        if let undoManager { registerUndo(on: undoManager) }
        publish()
        drain()
    }

    @discardableResult
    private func drain() -> Task<Void, Never> {
        if let draining { return draining }
        let task = Task { [self] in
            while let step = keeper.nextStep() {
                let result = await worker.perform(step)
                let reloads = keeper.reloads
                keeper.finish(result)
                if keeper.reloads != reloads { undoManager?.removeAllActions(withTarget: self) }
                publish()
            }
            publish()
            draining = nil
        }
        draining = task
        return task
    }

    private func publish() {
        let latest = keeper.document
        if latest != document { document = latest }
        if keeper.warning != warning { warning = keeper.warning }
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
