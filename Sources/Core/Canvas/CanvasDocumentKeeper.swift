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
    private var notice: CanvasDiskWarning?
    private var lastWritten: Data?
    private var writing: Data?
    private var pendingReload: PendingReload?
    private var saveRequested = false
    private var saveOverRequested = false
    private var readRequested = false
    private var stepInFlight = false

    public private(set) var recordedSteps = 0
    public private(set) var reloads = 0

    public init(opening result: CanvasDiskResult) {
        finish(result)
    }

    public var document: CanvasDocumentDecoding {
        if let session { return .document(session.document) }
        return refusal ?? .corrupt("This canvas has not been read.")
    }

    public var warning: CanvasDiskWarning? { hold ?? notice }

    public var undoDepth: Int { history.undoDepth }

    public mutating func apply(_ operations: [CanvasOperation], by author: CanvasAuthor) -> CanvasEditOutcome? {
        guard let before = session?.document, let outcome = session?.apply(operations, by: author) else { return nil }
        if case .applied = outcome, !operations.isEmpty {
            history.record(before: before)
            recordedSteps += 1
            saveRequested = true
        }
        return outcome
    }

    public mutating func beginEditing(_ element: CanvasElementID) {
        session?.beginEditing(element)
    }

    public mutating func undo() -> Bool {
        guard let current = session?.document, let restored = history.undo(current: current) else { return false }
        session?.restore(restored)
        saveRequested = true
        return true
    }

    public mutating func redo() -> Bool {
        guard let current = session?.document, let restored = history.redo(current: current) else { return false }
        session?.restore(restored)
        saveRequested = true
        return true
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
            notice = nil
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
            if case .saveFailed = notice { notice = nil }
        case .writeFailed(let reason):
            notice = .saveFailed(reason)
        case .outsideChange:
            writing = nil
            readRequested = true
            saveRequested = true
        case .backedUp(let path):
            backedUp(at: path)
        case .backupFailed(let reason):
            pendingReload = nil
            hold = .backupFailed(reason)
        }
    }

    private mutating func backupStep() -> CanvasDiskStep? {
        guard pendingReload != nil, let held = session?.document else { return nil }
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
            notice = .saveFailed(error.localizedDescription)
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
        guard let pending = pendingReload else { return }
        guard pending.backingUp == session?.document else { return }
        replace(with: pending.document, disk: pending.disk, backup: path)
    }

    private mutating func replace(with document: CanvasDocument, disk: Data, backup: String?) {
        session = CanvasDocumentSession(document: document)
        history = CanvasHistory()
        lastWritten = disk
        writing = nil
        pendingReload = nil
        saveRequested = false
        hold = nil
        reloads += 1
        if let backup {
            notice = .reloaded(backup: backup)
            return
        }
        if case .saveFailed = notice { notice = nil }
    }
}
