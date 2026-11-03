import Foundation

public struct CanvasDocumentKeeper: Sendable {
    private struct PendingReload: Sendable {
        let document: CanvasDocument
        let disk: Data
        var backingUp: CanvasDocument?
    }

    private var session: CanvasDocumentSession?
    private var refusal: CanvasDocumentDecoding?
    private var history = CanvasHistory()
    private var hold: CanvasDiskWarning?
    private var failure: CanvasDiskWarning?
    private var rescued: CanvasDiskWarning?
    private var notice: CanvasDiskWarning?
    private var revisionFloor = CanvasRevisionFloor()
    private var lastWritten: Data?
    private var writing: Data?
    private var pendingReload: PendingReload?
    private var saveRequested = false
    private var saveOverRequested = false
    private var readRequested = false
    private var stepInFlight = false

    public private(set) var draft: CanvasTextDraft?
    public private(set) var recordedSteps = 0
    public private(set) var reloads = 0

    public init(opening result: CanvasDiskResult) {
        finish(result)
    }

    public var document: CanvasDocumentDecoding {
        if let session { return .document(session.document) }
        return refusal ?? .corrupt("This canvas has not been read.")
    }

    public var warning: CanvasDiskWarning? { hold ?? failure ?? rescued ?? notice }

    public var hasStrandedEdits: Bool {
        let nothingPending = hold == nil && failure == nil && !stepInFlight && !saveRequested && pendingReload == nil
        guard !nothingPending, let held = session?.document else { return false }
        guard let lastWritten, case .document(let written) = CanvasDocumentCodec.decode(lastWritten) else { return true }
        return !CanvasDiskReconcile.sameContent(held, written)
    }

    public var undoDepth: Int { history.undoDepth }

    public mutating func apply(_ operations: [CanvasOperation], by author: CanvasAuthor) -> CanvasEditOutcome? {
        guard let before = session?.document, let outcome = session?.apply(operations, by: author) else { return nil }
        if case .applied = outcome, !operations.isEmpty {
            history.record(before: before)
            recordedSteps += 1
            saveRequested = true
        }
        rescueDraft(from: before)
        return outcome
    }

    public mutating func setDraft(_ next: CanvasTextDraft?) {
        draft = next
    }

    public mutating func finishDraft() {
        applyDraft()
        draft = nil
    }

    public mutating func beginEditing(_ element: CanvasElementID) {
        session?.beginEditing(element)
    }

    public mutating func undo() -> Bool {
        guard let current = session?.document, let restored = history.undo(current: current) else { return false }
        restore(restored, over: current)
        return true
    }

    public mutating func redo() -> Bool {
        guard let current = session?.document, let restored = history.redo(current: current) else { return false }
        restore(restored, over: current)
        return true
    }

    private mutating func restore(_ restored: CanvasDocument, over current: CanvasDocument) {
        session?.restore(restored)
        saveRequested = true
        rescueDraft(from: current)
    }

    public mutating func perform(_ action: CanvasDiskWarningAction) {
        switch action {
        case .saveOver, .saveAgain:
            guard session != nil else { return }
            hold = nil
            pendingReload = nil
            saveOverRequested = true
        case .tryAgain:
            saveRequested = true
        case .reload:
            readRequested = true
        case .dismiss:
            if rescued == nil { notice = nil }
            rescued = nil
        }
    }

    public mutating func nextStep() -> CanvasDiskStep? {
        guard !stepInFlight else { return nil }
        let step = backupStep() ?? deliberateSaveStep() ?? readStep() ?? saveStep()
        stepInFlight = step != nil
        return step
    }

    public mutating func finish(_ result: CanvasDiskResult) {
        stepInFlight = false
        switch result {
        case .read(let disk):
            settle(disk)
        case .unreadable(let reason):
            settleUnreadable(reason)
        case .written(let data):
            lastWritten = data
            writing = nil
            failure = nil
        case .savedOver(let data, let backup):
            lastWritten = data
            writing = nil
            failure = nil
            notice = .savedOver(backups: (notice?.keptCopies ?? []) + [backup], typingKeptIn: notice?.typingCopies ?? [])
        case .saveOverFailed(let reason, let backup):
            failure = .saveFailed("\(reason) What was on disk is kept in \((backup as NSString).lastPathComponent).")
            notice = .copyKept(backups: (notice?.keptCopies ?? []) + [backup], typingKeptIn: notice?.typingCopies ?? [])
        case .saveOverRefused(let reason):
            writing = nil
            hold = .saveOverRefused(reason)
            saveRequested = true
        case .writeFailed(let reason):
            failure = .saveFailed(reason)
        case .outsideChange:
            writing = nil
            readRequested = true
            saveRequested = true
        case .backedUp(let path):
            backedUp(at: path)
        case .backupFailed(let reason):
            guard pendingReload != nil else { return }
            pendingReload = nil
            hold = .backupFailed(reason)
        }
    }

    private mutating func backupStep() -> CanvasDiskStep? {
        guard pendingReload != nil else { return nil }
        applyDraft()
        guard let held = session?.document else { return nil }
        do {
            let data = try CanvasDocumentCodec.encode(held)
            pendingReload?.backingUp = held
            return .backup(data)
        } catch {
            pendingReload = nil
            hold = .backupFailed(error.localizedDescription)
            return nil
        }
    }

    private mutating func deliberateSaveStep() -> CanvasDiskStep? {
        guard saveOverRequested, let held = session?.document else { return nil }
        saveOverRequested = false
        saveRequested = false
        return encodedSave(of: held, expecting: nil)
    }

    private mutating func readStep() -> CanvasDiskStep? {
        guard readRequested else { return nil }
        readRequested = false
        return .read
    }

    private mutating func saveStep() -> CanvasDiskStep? {
        guard saveRequested, hold == nil, let held = session?.document else { return nil }
        saveRequested = false
        return encodedSave(of: held, expecting: [lastWritten, writing].compactMap(\.self))
    }

    private mutating func encodedSave(of held: CanvasDocument, expecting: [Data]?) -> CanvasDiskStep? {
        do {
            let data = try CanvasDocumentCodec.encode(held)
            if expecting != nil, data == lastWritten { return nil }
            writing = data
            return .save(data, expecting: expecting)
        } catch {
            failure = .saveFailed(error.localizedDescription)
            return nil
        }
    }

    private mutating func settle(_ disk: Data?) {
        guard !saveOverRequested else { return }
        guard let held = session?.document else {
            adopt(disk)
            return
        }
        switch CanvasDiskReconcile.decide(disk: disk, lastWritten: lastWritten, held: held, writing: writing) {
        case .unchanged:
            if disk == writing {
                lastWritten = writing
                writing = nil
                failure = nil
            }
            hold = nil
        case .reload(let document, let keepBackup):
            guard let disk else { return }
            if keepBackup {
                pendingReload = PendingReload(document: document, disk: disk)
            } else {
                replace(with: document, disk: disk, backup: nil)
            }
        case .refused(let reason):
            hold = .refused(reason)
        case .vanished:
            hold = .vanished
        }
    }

    private mutating func settleUnreadable(_ reason: String) {
        guard session != nil else {
            refusal = .corrupt(reason)
            return
        }
        if !saveOverRequested { hold = .refused("The file on disk cannot be read: \(reason)") }
    }

    private mutating func adopt(_ disk: Data?) {
        guard let disk else {
            refusal = .corrupt("This canvas is not on disk.")
            return
        }
        let decoding = CanvasDocumentCodec.decode(disk)
        guard case .document(let document) = decoding else {
            refusal = decoding
            return
        }
        session = CanvasDocumentSession(document: document)
        refusal = nil
        lastWritten = disk
    }

    private mutating func backedUp(at path: String) {
        applyDraft()
        guard let pending = pendingReload else { return }
        guard pending.backingUp == session?.document else { return }
        replace(with: pending.document, disk: pending.disk, backup: path)
    }

    private mutating func replace(with document: CanvasDocument, disk: Data, backup: String?) {
        if let held = session?.document { revisionFloor.note(held) }
        history.heldDocuments.forEach { revisionFloor.note($0) }
        let lostTyping = draft.map { draft in !document.elements.contains { $0.id == draft.elementID } } ?? false
        if lostTyping { draft = nil }
        session = CanvasDocumentSession(document: revisionFloor.raising(document))
        history = CanvasHistory()
        lastWritten = disk
        writing = nil
        pendingReload = nil
        saveRequested = false
        hold = nil
        failure = nil
        reloads += 1
        guard let backup else { return }
        notice = .reloaded(
            backups: (notice?.keptCopies ?? []) + [backup],
            typingKeptIn: (notice?.typingCopies ?? []) + (lostTyping ? [backup] : [])
        )
    }

    private mutating func applyDraft() {
        guard let draft, let held = session?.document,
              held.elements.first(where: { $0.id == draft.elementID })?.text != draft.text else { return }
        let operations = CanvasEditing.operations(
            finishing: draft.elementID, original: draft.original, edited: draft.text,
            measuredHeight: draft.measuredHeight, in: held
        )
        if !operations.isEmpty { _ = apply(operations, by: .owner) }
    }

    private mutating func rescueDraft(from before: CanvasDocument) {
        guard let draft, let held = session?.document,
              !held.elements.contains(where: { $0.id == draft.elementID }),
              let lost = before.elements.first(where: { $0.id == draft.elementID }) else { return }
        var element = lost
        element.kind = lost.kind(replacingTextWith: draft.text)
        element.revision += 1
        if let frameID = lost.frameID, !held.frames.contains(where: { $0.id == frameID }) {
            element.frameID = nil
            element.rect = CanvasHitTest.absoluteRect(of: lost, in: before)
        }
        _ = session?.apply([.addElement(element)], by: .owner)
        saveRequested = true
        rescued = .draftRescued
    }
}
