import AppKit
import SwiftUI
import Core

#if DEBUG
@MainActor
enum CanvasCommentsProbe {
    private static let size = NSSize(width: 1_200, height: 800)
    private static let first = CanvasViewport(zoom: 0.4, offset: CanvasPoint(x: 120, y: 80))
    private static let second = CanvasViewport(zoom: 0.25, offset: CanvasPoint(x: 500, y: 200))
    private static let stopped = CanvasPoint(x: 800, y: 200)

    static func run(in directory: String) -> [String] {
        var failures: [String] = []
        func check(_ condition: Bool, _ message: String) {
            if !condition { failures.append("comments: \(message)") }
        }
        let path = directory + "/comments-\(UUID().uuidString).udcanvas"
        let plain = plainPath(directory)
        let seeded = document()
        var bare = seeded
        bare.comments = []
        guard (try? CanvasDocumentFile.write(seeded, to: path)) != nil,
              (try? CanvasDocumentFile.write(bare, to: plain)) != nil else { return ["comments: could not seed"] }
        defer {
            try? FileManager.default.removeItem(atPath: path)
            try? FileManager.default.removeItem(atPath: plain)
        }

        let model = CanvasDocumentModel(path: path, worktree: directory)
        model.commentCourier = CanvasCommentCourier(send: { _ in .awaitingChat }, cancel: { _, _ in true }, wait: wait)
        model.confirmCommentDeliveries(Set(["stopped", "draft", "question", "turn", "ahead"].map { DeliveryID($0) }))
        model.changeComments { CanvasCommentFlow.started(CanvasCommentID("working"), in: $0) }
        let withoutMarks = CanvasDocumentModel(path: plain, worktree: directory)

        check(!model.commentMarks.contains { $0.id == CanvasCommentID("row-gone") }, "a queued comment with no confirmed row has a mark")
        check(!model.commentMarks.contains { $0.state == .resolved || $0.state == .declined }, "an answered comment still has a mark")
        check(model.listedComments.contains { $0.state == .declined && $0.response != nil }, "the declined reason is not in the list")

        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            failures += shoot(editor(model, first), appearance, "\(directory)/comments-marks-\(name).png")
            failures += shoot(editor(model, first, list: true), appearance, "\(directory)/comments-list-\(name).png")
            let cards = cardGallery(model).frame(width: 720, height: 420).background(Color(nsColor: .windowBackgroundColor))
            failures += CanvasEditorProbe.shoot(cards, appearance: appearance, to: "\(directory)/comments-cards-\(name).png", size: NSSize(width: 720, height: 420))
        }
        failures += shoot(editor(model, second), .aqua, "\(directory)/comments-moved-light.png")
        failures += shoot(editor(withoutMarks, first), .aqua, "\(directory)/comments-bare-first.png")
        failures += shoot(editor(withoutMarks, second), .aqua, "\(directory)/comments-bare-second.png")
        failures += shoot(editor(withoutMarks, first, list: true), .aqua, "\(directory)/comments-empty-light.png")
        failures += marksFollowTheViewport(in: directory)
        failures += marksStayOutOfTheFrame(seeded: seeded, bare: bare, directory: directory)
        failures += modelChecks(in: directory)
        return failures
    }

    private static func plainPath(_ directory: String) -> String { directory + "/comments-bare.udcanvas" }

    private static func editor(_ model: CanvasDocumentModel, _ viewport: CanvasViewport, list: Bool = false) -> some View {
        CanvasEditorView(model: model, revision: 0, initialViewport: viewport, initialShowsCommentList: list)
            .frame(width: size.width, height: size.height)
    }

    private static func shoot(_ content: some View, _ appearance: NSAppearance.Name, _ path: String) -> [String] {
        CanvasEditorProbe.shoot(content, appearance: appearance, to: path, size: size)
    }

    private static func cardGallery(_ model: CanvasDocumentModel) -> some View {
        let controls = CanvasCommentControls(model: model)
        return HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                CanvasCommentComposer(action: "Comment", commit: { _ in }, cancel: {})
                ForEach(controls.listed.filter { $0.state == .unanswered }) { CanvasCommentRow(comment: $0, comments: controls) }
            }
            .frame(width: 300)
            VStack(alignment: .leading, spacing: 16) {
                ForEach(controls.listed.filter { $0.id == CanvasCommentID("stopped") || $0.state == .declined }) {
                    CanvasCommentRow(comment: $0, comments: controls)
                }
            }
            .frame(width: 300)
        }
        .padding(24)
    }

    private static func wait(_ comment: CanvasComment) -> CanvasCommentWait? {
        switch comment.id.rawValue {
        case "no-chat": .noChat
        case "stopped": .stoppedByHand
        case "draft": .draftBeingEdited
        case "question": .held(.question)
        case "turn": .held(.turn)
        case "ahead": .commentAhead
        default: nil
        }
    }

    private static func marksFollowTheViewport(in directory: String) -> [String] {
        func picture(_ name: String) -> NSBitmapImageRep? {
            (try? Data(contentsOf: URL(filePath: "\(directory)/\(name).png"))).flatMap(NSBitmapImageRep.init(data:))
        }
        guard let marked = picture("comments-marks-light"), let moved = picture("comments-moved-light"),
              let bareFirst = picture("comments-bare-first"), let bareSecond = picture("comments-bare-second") else {
            return ["comments: a picture is missing"]
        }
        var failures: [String] = []
        let atFirst = first.toScreen(stopped)
        let atSecond = second.toScreen(stopped)
        if !differs(marked, bareFirst, at: atFirst) { failures.append("comments: no mark where the first viewport puts it") }
        if !differs(moved, bareSecond, at: atSecond) { failures.append("comments: no mark where the second viewport puts it") }
        if differs(moved, bareSecond, at: atFirst) { failures.append("comments: the mark stayed behind when the viewport moved") }
        return failures
    }

    private static func differs(_ one: NSBitmapImageRep, _ two: NSBitmapImageRep, at point: CanvasPoint) -> Bool {
        let scale = Double(one.pixelsWide) / size.width
        let x = Int((point.x - 8) * scale)
        let y = Int(point.y * scale)
        guard let a = one.colorAt(x: x, y: y)?.usingColorSpace(.genericRGB),
              let b = two.colorAt(x: x, y: y)?.usingColorSpace(.genericRGB) else { return false }
        return abs(a.redComponent - b.redComponent) + abs(a.greenComponent - b.greenComponent) + abs(a.blueComponent - b.blueComponent) > 0.1
    }

    private static func marksStayOutOfTheFrame(seeded: CanvasDocument, bare: CanvasDocument, directory: String) -> [String] {
        guard let frame = seeded.frames.first,
              let with = CanvasFrameRenderer.png(frame: frame, document: seeded, documentPath: directory + "/x.udcanvas", worktree: directory),
              let without = CanvasFrameRenderer.png(frame: frame, document: bare, documentPath: directory + "/x.udcanvas", worktree: directory) else {
            return ["comments: the frame did not render"]
        }
        return with == without ? [] : ["comments: the export of a frame changed because of its comments"]
    }

    private static func modelChecks(in directory: String) -> [String] {
        var failures: [String] = []
        func check(_ condition: Bool, _ message: String) {
            if !condition { failures.append("comments model: \(message)") }
        }
        func settle(until done: () -> Bool) -> Bool {
            let deadline = Date(timeIntervalSinceNow: 5)
            while !done(), Date() < deadline { RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02)) }
            return done()
        }
        let path = directory + "/comments-model-\(UUID().uuidString).udcanvas"
        defer { try? FileManager.default.removeItem(atPath: path) }
        var base = document()
        base.comments = []
        guard (try? CanvasDocumentFile.write(base, to: path)) != nil else { return ["comments model: could not seed"] }
        let model = CanvasDocumentModel(path: path, worktree: directory)
        func onDisk() -> CanvasDocument? {
            if case .document(let held)? = try? CanvasDocumentFile.read(at: path) { return held }
            return nil
        }
        func comment(_ id: CanvasCommentID?) -> CanvasComment? {
            model.listedComments.first { $0.id == id }
        }

        let box = base.elements[0]
        model.apply([.updateElement(box.id, expectedRevision: nil, CanvasElementPatch(rect: CanvasRect(x: 9, y: 9, width: 50, height: 50)))])

        var added: CanvasCommentID?
        Task { added = await model.addComment(at: CanvasPoint(x: 20, y: 20), text: "Bigger") }
        check(settle { added != nil }, "a comment was not added")
        check(settle { onDisk()?.comments.first?.text == "Bigger" }, "a comment did not reach the file")
        check(comment(added)?.frameID == base.frames[0].id, "the comment does not name its frame")

        model.undoManager.undo()
        check(comment(added) != nil, "undo took the comment")

        var resolved: CanvasCommentResolveOutcome?
        let order = CanvasCommentResolveOrder(
            path: path, commentID: added ?? CanvasCommentID("none"), state: .declined, response: "No room.", caller: SessionID("chat")
        )
        model.changeComments { CanvasCommentDelivery.assigned(order.commentID, to: DeliveryID("handed"), in: $0) }
        Task { resolved = await model.resolveComment(order, handover: CanvasCommentHandover(delivery: DeliveryID("handed"), target: SessionID("chat"))) }
        check(settle { resolved != nil }, "a resolve did not finish")
        if case .resolved(let result)? = resolved {
            check(result.disk == .saved, "a resolve was not saved: \(result.disk)")
        } else {
            failures.append("comments model: the resolve was refused: \(String(describing: resolved))")
        }
        check(onDisk()?.comments.first?.state == .declined, "the declined state is not in the file")
        check(onDisk()?.comments.first?.response == "No room.", "the reason is not in the file")
        check(!model.commentMarks.contains { $0.id == order.commentID }, "a declined comment still has a mark")
        check(model.unreadDeclinedComments.map(\.id) == [order.commentID], "a declined comment is not unread")
        model.undoManager.redo()
        check(comment(added)?.state == .declined, "redo touched the comment")

        var deleted = false
        Task { deleted = await model.deleteQueued(order.commentID) }
        check(settle { deleted }, "a declined comment could not be deleted")
        check(settle { onDisk()?.comments.isEmpty == true }, "the deletion did not reach the file")
        return failures
    }

    private static func comment(
        _ id: String, _ state: CanvasComment.State, _ x: Double, _ y: Double, _ text: String, delivery: String? = nil, response: String? = nil
    ) -> CanvasComment {
        CanvasComment(
            id: CanvasCommentID(id), anchor: CanvasPoint(x: x, y: y), text: text, state: state, response: response,
            deliveryID: delivery.map { DeliveryID($0) }, createdAt: Date(timeIntervalSince1970: x + y)
        )
    }

    private static func document() -> CanvasDocument {
        let slide = CanvasFrame(id: CanvasFrameID("f1"), name: "Slide 1", rect: CanvasRect(x: 0, y: 0, width: 1_080, height: 1_350))
        let dark = CanvasFrame(id: CanvasFrameID("f2"), name: "Slide 2", rect: CanvasRect(x: 1_200, y: 0, width: 1_080, height: 1_350), fill: "#1F2937")
        let box = CanvasElement(
            id: CanvasElementID("box"), frameID: slide.id, rect: CanvasRect(x: 100, y: 100, width: 500, height: 300),
            style: CanvasStyle(fill: "#BFDBFE"), kind: .shape(CanvasShape(kind: .rectangle))
        )
        return CanvasDocument(frames: [slide, dark], elements: [box], comments: [
            comment("no-chat", .queued, 150, 500, "Move this up a little."),
            comment("stopped", .queued, stopped.x, stopped.y, "Use the brand blue here.", delivery: "stopped"),
            comment("draft", .queued, 150, 800, "Tighten this line.", delivery: "draft"),
            comment("question", .queued, 800, 600, "Should this be a chart?", delivery: "question"),
            comment("turn", .queued, 150, 1_100, "Bigger heading.", delivery: "turn"),
            comment("ahead", .queued, 1_400, 200, "And this one too.", delivery: "ahead"),
            comment("working", .unanswered, 1_400, 600, "Swap the picture.", delivery: "working"),
            comment("unanswered", .unanswered, 1_400, 900, "Why is this so small?", delivery: "unanswered"),
            comment("row-gone", .queued, 800, 1_000, "This row went away.", delivery: "gone"),
            comment("done", .resolved, 800, 1_200, "Fix the margin.", delivery: "done", response: "Set the margin to 80 points."),
            comment("refused", .declined, 1_800, 1_200, "Delete every slide.", delivery: "refused", response: "That would lose the deck, so ask me again if you mean it."),
        ])
    }
}
#endif
