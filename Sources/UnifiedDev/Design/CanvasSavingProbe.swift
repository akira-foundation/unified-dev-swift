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
        let model = CanvasDocumentModel(path: path, worktree: directory)
        let undo = model.undoManager

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
        func frameName() -> String? {
            guard case .document(let document) = model.document else { return nil }
            return document.frames.first?.name
        }
        check(settle { frameName() == "From git" }, "an outside change was not reloaded")
        if case .reloaded(let backups, _) = model.warning, let backup = backups.last {
            check(FileManager.default.fileExists(atPath: backup), "the warning names a copy that is not there")
        } else {
            failures.append("saving: the reload did not warn, it says \(String(describing: model.warning))")
        }
        check(!undo.canUndo && !undo.canRedo, "a reload left undo steps behind")

        _ = move(70)
        check(settle { onDisk() == model.document }, "saving did not resume after a reload")
        _ = move(71)
        _ = move(72)
        undo.undo()
        check(x() == 71, "two edits in one turn did not undo one at a time")
        undo.undo()
        check(x() == 70, "the second undo did not step back one edit")
        undo.redo()
        check(x() == 71, "redo did not step forward one edit")
        check(settle { onDisk() == model.document }, "stepping through undo did not reach the disk")
        failures += responderChecks(model: model, undoStep: { x() })
        failures += typedSizeChecks(in: directory)

        model.startEditing(box, text: CanvasText(runs: []))
        check(model.editing != nil, "editing did not start in the model")
        model.finishEditing()

        try? FileManager.default.removeItem(atPath: path)
        model.requestReconcile()
        check(settle { model.warning == .vanished }, "a deleted file did not warn")
        _ = move(90)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        check(!FileManager.default.fileExists(atPath: path), "a deleted file was recreated silently")
        model.perform(.saveAgain)
        check(settle { onDisk() == model.document }, "save again did not write")
        check(model.warning == nil || model.warning?.tone != .error, "save again left an error showing")
        return failures
    }

    private static func typedSizeChecks(in directory: String) -> [String] {
        let path = directory + "/typed-size-\(UUID().uuidString).udcanvas"
        defer { try? FileManager.default.removeItem(atPath: path) }
        let title = CanvasElementID("title")
        let run = CanvasTextRun(text: "Title", fontName: "Helvetica", size: 12, weight: 400, colour: "#000000")
        let text = CanvasText(runs: [run])
        let frame = CanvasFrame(name: "One", rect: CanvasRect(x: 0, y: 0, width: 400, height: 400))
        let seeded = CanvasDocument(frames: [frame], elements: [
            CanvasElement(id: title, frameID: frame.id, rect: CanvasRect(x: 1, y: 1, width: 300, height: 60), kind: .text(text)),
        ])
        guard (try? CanvasDocumentFile.write(seeded, to: path)) != nil else { return ["saving: could not seed \(path)"] }
        let model = CanvasDocumentModel(path: path, worktree: directory)
        model.startEditing(title, text: text)
        let field = CanvasCoalescedCommit(delay: .seconds(3_600))
        model.pendingCommits.add(field)
        field.schedule { model.editing?.apply(CanvasRunChange(size: 24)) }

        model.finishEditing()

        guard case .document(let document) = model.document,
              document.elements.first(where: { $0.id == title })?.text?.runs.first?.size == 24 else {
            return ["saving: a size typed during text editing was lost when the edit closed"]
        }
        return []
    }

    private static func responderChecks(model: CanvasDocumentModel, undoStep: () -> Double?) -> [String] {
        var failures: [String] = []
        let window = NSWindow(contentRect: NSRect(x: -20_000, y: -20_000, width: 300, height: 200), styleMask: [.borderless], backing: .buffered, defer: true)
        let responder = CanvasUndoResponderView()
        responder.canvasUndo = model.undoManager
        let composer = NSTextView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        composer.allowsUndo = true
        window.contentView?.addSubview(responder)
        window.contentView?.addSubview(composer)
        let before = undoStep()

        window.makeFirstResponder(composer)
        composer.insertText("typed", replacementRange: NSRange(location: 0, length: 0))
        _ = composer.tryToPerform(#selector(CanvasUndoResponderView.undo(_:)), with: nil)
        if undoStep() != before { failures.append("saving: undo in another text view reached the canvas") }
        if !composer.string.isEmpty { failures.append("saving: undo in another text view did not undo its typing") }

        window.makeFirstResponder(responder)
        let handled = responder.tryToPerform(#selector(CanvasUndoResponderView.undo(_:)), with: nil)
        if !handled || undoStep() == before { failures.append("saving: undo with the canvas focused did not reach the canvas") }
        model.undoManager.redo()

        let focus = CanvasUndoFocus()
        focus.view = responder
        window.makeFirstResponder(composer)
        focus.returnAfterEditing()
        if window.firstResponder !== composer { failures.append("saving: closing an edit took focus from another text view") }
        window.makeFirstResponder(nil)
        focus.returnAfterEditing()
        if window.firstResponder !== responder { failures.append("saving: closing an edit did not return focus when nothing held it") }
        let closing = CanvasEditingTextView(frame: NSRect(x: 0, y: 0, width: 10, height: 10))
        window.contentView?.addSubview(closing)
        window.makeFirstResponder(closing)
        focus.returnAfterEditing()
        if window.firstResponder !== responder { failures.append("saving: closing an edit did not take focus back from its editor") }

        let item = NSMenuItem(title: "Undo", action: #selector(CanvasUndoResponderView.undo(_:)), keyEquivalent: "z")
        if !responder.validateMenuItem(item) { failures.append("saving: the Undo item is disabled with steps to undo") }
        return failures
    }
}
#endif
