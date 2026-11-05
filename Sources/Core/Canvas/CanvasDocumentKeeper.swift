import Foundation

public struct CanvasDocumentKeeper: Sendable {
    private var session: CanvasDocumentSession?
    private var refusal: CanvasDocumentDecoding?
    private var history = CanvasHistory()
    private var hold: CanvasDiskWarning? {
        didSet {
            if oldValue?.refusesAgentEdits == true, hold?.refusesAgentEdits != true { holdsLifted += 1 }
        }
    }
    private var failure: CanvasDiskWarning?
    private var rescued: CanvasDiskWarning?
    private var copies = CanvasKeptCopies()
    private var revisionFloor = CanvasRevisionFloor()
    private var lastWritten: Data?
    private var writing: Data?
    private var pendingReload: CanvasPendingReload?
    private var saveRequested = false
    private var saveOverRequested = false
    private var deliberateSaveUnfinished = false
    private var readRequested = false
    private var stepInFlight = false
    private var ownerEdited = false
    private var copyHoldsOwnerWork = false

    public private(set) var draft: CanvasTextDraft?
    public private(set) var recordedSteps = 0
    public private(set) var reloads = 0
    public private(set) var holdsLifted = 0

    public init(opening result: CanvasDiskResult) {
        finish(result)
    }

    public var document: CanvasDocumentDecoding {
        if let session { return .document(session.document) }
        return refusal ?? .corrupt("This canvas has not been read.")
    }

    public var warning: CanvasDiskWarning? { hold ?? failure ?? rescued ?? copies.notice }

    public var holdsCanvasComments: Bool { warning?.refusesAgentEdits == true }

    public var hasStrandedEdits: Bool {
        let nothingPending = hold == nil && failure == nil && !stepInFlight && !saveRequested && pendingReload == nil
        return !nothingPending && heldDiffersFromFile
    }

    public var copiesHoldingOwnerWork: [String] { copies.holdingOwnerWork }

    private var heldDiffersFromFile: Bool {
        guard let held = session?.document else { return false }
        guard let lastWritten, case .document(let written) = CanvasDocumentCodec.decode(lastWritten) else { return true }
        return !CanvasDiskReconcile.sameContent(held, written)
    }

    public var undoDepth: Int { history.undoDepth }

    public mutating func apply(_ operations: [CanvasOperation], by author: CanvasAuthor) -> CanvasEditOutcome? {
        guard let before = session?.document, let outcome = session?.apply(operations, by: author) else { return nil }
        if case .applied = outcome, !operations.isEmpty {
            history.record(before: before)
            let after = session?.document ?? before
            session?.restore(CanvasCommentAnchors.following(from: before, to: after, remembering: history.commentLinks))
            recordedSteps += 1
            saveRequested = true
            if author == .owner { ownerEdited = true }
        }
        rescueDraft(from: before)
        guard case .applied = outcome, let held = session?.document else { return outcome }
        return .applied(held)
    }

    public mutating func changeComments(_ change: (CanvasDocument) -> CanvasDocument) {
        guard let held = session?.document else { return }
        let changed = change(held)
        guard changed != held else { return }
        session?.restore(changed)
        saveRequested = true
    }

    public mutating func setDraft(_ next: CanvasTextDraft?) { draft = next }

    public mutating func finishDraft() {
        applyDraft()
        draft = nil
    }

    public mutating func beginEditing(_ element: CanvasElementID) { session?.beginEditing(element) }

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
        session?.restore(CanvasCommentAnchors.following(from: current, to: restored, remembering: history.commentLinks))
        saveRequested = true
        ownerEdited = true
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
            if deliberateSaveUnfinished { saveOverRequested = true } else { saveRequested = true }
        case .reload:
            readRequested = true
        case .dismiss:
            if rescued == nil { copies.dismiss() }
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
            landed()
        case .savedOver(let data, let backup):
            lastWritten = data
            landed()
            copies.savedOver(keeping: backup)
        case .saveOverFailed(let reason, let backup):
            failure = .saveFailed("\(reason) What was on disk is kept in \((backup as NSString).lastPathComponent).")
            copies.kept(backup, holdsOwnerWork: false)
        case .saveOverRefused(let reason):
            writing = nil
            deliberateSaveUnfinished = false
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

    private mutating func landed() {
        writing = nil
        failure = nil
        deliberateSaveUnfinished = false
    }

    private mutating func backupStep() -> CanvasDiskStep? {
        guard pendingReload != nil else { return nil }
        applyDraft()
        guard let held = session?.document else { return nil }
        do {
            let data = try CanvasDocumentCodec.encode(held)
            pendingReload?.backingUp = held
            copyHoldsOwnerWork = ownerEdited
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
        deliberateSaveUnfinished = true
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
                landed()
            }
            hold = nil
        case .reload(let document, let keepBackup):
            guard let disk else { return }
            if keepBackup {
                pendingReload = CanvasPendingReload(document: document, disk: disk)
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
        guard let pending = pendingReload, pending.backingUp == session?.document else {
            copies.kept(path, holdsOwnerWork: copyHoldsOwnerWork)
            return
        }
        replace(with: pending.document, disk: pending.disk, backup: path)
    }

    private mutating func replace(with document: CanvasDocument, disk: Data, backup: String?) {
        if let held = session?.document { revisionFloor.note(held) }
        history.heldDocuments.forEach { revisionFloor.note($0) }
        let lostTyping = draft.map { draft in !document.elements.contains { $0.id == draft.elementID } } ?? false
        if lostTyping { draft = nil }
        let merged = session.map { CanvasCommentFlow.afterReload(document, replacing: $0.document) } ?? document
        session = CanvasDocumentSession(document: revisionFloor.raising(merged))
        history = CanvasHistory()
        lastWritten = disk
        landed()
        pendingReload = nil
        saveRequested = merged.comments != document.comments
        hold = nil
        reloads += 1
        guard let backup else { return }
        copies.reloaded(keeping: backup, lostTyping: lostTyping, holdsOwnerWork: copyHoldsOwnerWork)
        ownerEdited = false
    }

    private mutating func applyDraft() {
        guard let draft, let held = session?.document else { return }
        let operations = draft.operations(finishingIn: held)
        if !operations.isEmpty { _ = apply(operations, by: .owner) }
    }

    private mutating func rescueDraft(from before: CanvasDocument) {
        guard let held = session?.document,
              let element = draft?.rescuedElement(missingFrom: held, before: before) else { return }
        _ = session?.apply([.addElement(element)], by: .owner)
        saveRequested = true
        ownerEdited = true
        rescued = .draftRescued
    }
}
