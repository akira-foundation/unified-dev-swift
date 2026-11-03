import AppKit
import Core

#if DEBUG
@MainActor
enum CanvasSavingProbe {
    static func run(in directory: String) -> [String] {
        var failures: [String] = []
        func check(_ condition: Bool, _ message: String) {
            if !condition { failures.append("saving: \(message)") }
        }
        let path = directory + "/saving-\(UUID().uuidString).udcanvas"
        let box = CanvasElementID("box")
        let frame = CanvasFrame(name: "One", rect: CanvasRect(x: 0, y: 0, width: 100, height: 100))
        let original = CanvasDocument(frames: [frame], elements: [
            CanvasElement(id: box, frameID: frame.id, rect: CanvasRect(x: 1, y: 1, width: 10, height: 10), kind: .shape(CanvasShape(kind: .rectangle))),
        ])
        guard (try? CanvasDocumentFile.write(original, to: path)) != nil else { return ["saving: could not seed \(path)"] }
        let undo = UndoManager()
        let model = CanvasDocumentModel(path: path, worktree: directory)
        model.attachUndo(undo)

        func onDisk() -> CanvasDocumentDecoding? { try? CanvasDocumentFile.read(at: path) }
        func settle(until done: () -> Bool) -> Bool {
            let deadline = Date(timeIntervalSinceNow: 5)
            while !done(), Date() < deadline { RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02)) }
            return done()
        }
        func move(_ x: Double, by author: CanvasAuthor = .owner, revision: Int? = nil) -> CanvasEditOutcome? {
            model.apply([.updateElement(box, expectedRevision: revision, CanvasElementPatch(rect: CanvasRect(x: x, y: 1, width: 10, height: 10)))], by: author)
        }
        func x() -> Double? {
            guard case .document(let document) = model.document else { return nil }
            return document.elements.first { $0.id == box }?.rect.origin.x
        }

        _ = move(50)
        check(settle { onDisk() == model.document }, "an edit did not reach the disk")
        let reopened = CanvasDocumentModel(path: path, worktree: directory)
        check(reopened.document == model.document, "the edit did not survive reopening")

        undo.undo()
        check(x() == 1, "undo did not restore the element")
        check(settle { onDisk() == model.document }, "undo did not reach the disk")
        if case .conflict = move(9, by: .agent, revision: 0) {} else { failures.append("saving: a stale agent revision survived undo") }
        undo.redo()
        check(x() == 50, "redo did not restore the edit")
        check(settle { onDisk() == model.document }, "redo did not reach the disk")

        var outside = original
        outside.frames[0].name = "From git"
        guard (try? CanvasDocumentFile.write(outside, to: path)) != nil else { return failures + ["saving: outside write failed"] }
        model.requestReconcile()
        check(settle { model.document == .document(outside) }, "an outside change was not reloaded")
        if case .reloaded(let backup) = model.warning {
            check(FileManager.default.fileExists(atPath: backup), "the warning names a copy that is not there")
        } else {
            failures.append("saving: the reload did not warn, it says \(String(describing: model.warning))")
        }
        check(!undo.canUndo && !undo.canRedo, "a reload left undo steps behind")

        _ = move(70)
        check(settle { onDisk() == model.document }, "saving did not resume after a reload")
        model.attachUndo(nil)
        check(!undo.canUndo, "detaching left undo steps behind")
        _ = move(71)
        _ = move(72)
        model.attachUndo(undo)
        undo.undo()
        check(x() == 71, "steps made with the tab closed do not undo one at a time")
        check(settle { onDisk() == model.document }, "a step undone after reattaching did not reach the disk")

        try? FileManager.default.removeItem(atPath: path)
        model.requestReconcile()
        check(settle { model.warning == .vanished }, "a deleted file did not warn")
        _ = move(90)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        check(!FileManager.default.fileExists(atPath: path), "a deleted file was recreated silently")
        model.perform(.saveAgain)
        check(settle { onDisk() == model.document }, "save again did not write")
        check(model.warning == nil || model.warning?.tone != .error, "save again left an error showing")
        model.attachUndo(nil)
        return failures
    }
}
#endif
