import Foundation

struct CanvasKeptCopies: Sendable {
    private(set) var notice: CanvasDiskWarning?
    private(set) var holdingOwnerWork: [String] = []

    private var named: [String] { notice?.keptCopies ?? [] }
    private var typing: [String] { notice?.typingCopies ?? [] }

    mutating func reloaded(keeping copy: String, lostTyping: Bool, holdsOwnerWork: Bool) {
        notice = .reloaded(backups: named + [copy], typingKeptIn: typing + (lostTyping ? [copy] : []))
        if holdsOwnerWork { holdingOwnerWork.append(copy) }
    }

    mutating func savedOver(keeping copy: String) {
        notice = .savedOver(backups: named + [copy], typingKeptIn: typing)
    }

    mutating func kept(_ copy: String, holdsOwnerWork: Bool) {
        notice = .copyKept(backups: named + [copy], typingKeptIn: typing)
        if holdsOwnerWork { holdingOwnerWork.append(copy) }
    }

    mutating func dismiss() {
        notice = nil
        holdingOwnerWork = []
    }
}
