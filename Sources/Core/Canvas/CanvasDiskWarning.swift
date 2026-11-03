import Foundation

public enum CanvasDiskWarningAction: Sendable, Equatable, Hashable {
    case saveOver, saveAgain, tryAgain, reload, dismiss

    public var title: String {
        switch self {
        case .saveOver: "Save Over It"
        case .saveAgain: "Save Again"
        case .tryAgain: "Try Again"
        case .reload: "Reload"
        case .dismiss: "OK"
        }
    }
}

public enum CanvasDiskWarning: Sendable, Equatable {
    case saveFailed(String)
    case refused(String)
    case backupFailed(String)
    case saveOverRefused(String)
    case vanished
    case reloaded(backups: [String], typingKeptIn: [String])
    case savedOver(backups: [String], typingKeptIn: [String])
    case copyKept(backups: [String], typingKeptIn: [String])
    case draftRescued

    public var title: String {
        switch self {
        case .saveFailed: "This canvas is not saved"
        case .refused: "Saving is paused"
        case .backupFailed: "The file changed, and it was not reloaded"
        case .saveOverRefused: "The file on disk was not replaced"
        case .vanished: "This canvas is no longer on disk"
        case .reloaded: "The file changed on disk, so it was reloaded"
        case .savedOver: "The file on disk was replaced"
        case .copyKept: "A copy of this canvas was kept"
        case .draftRescued: "The text you are typing was removed"
        }
    }

    public var message: String {
        switch self {
        case .saveFailed(let reason):
            "Your edits are in this tab, and only there. Saving will be tried again on your next edit. \(reason)"
        case .refused(let reason):
            "Your edits are in this tab, and only there. The file is left as it is. \(reason)"
        case .backupFailed(let reason):
            "A copy of your version could not be written, so nothing was replaced and saving is paused. \(reason)"
        case .saveOverRefused(let reason):
            "A copy of what is on disk could not be written, so nothing was replaced and saving is paused. \(reason)"
        case .vanished:
            "Saving is paused, and your edits are in this tab, and only there. The file will not be recreated unless you save it again."
        case .reloaded(let backups, let typing):
            "Earlier versions are kept beside it, in \(Self.names(backups))." + Self.typingSentence(typing)
        case .savedOver(let backups, let typing):
            "What was there is kept beside it, in \(Self.names(backups))." + Self.typingSentence(typing)
        case .copyKept(let backups, let typing):
            "It is beside the file, in \(Self.names(backups))." + Self.typingSentence(typing)
        case .draftRescued:
            "Another edit removed the element, so it was put back to keep your text."
        }
    }

    public var actions: [CanvasDiskWarningAction] {
        switch self {
        case .saveFailed: [.tryAgain]
        case .refused, .backupFailed, .saveOverRefused: [.saveOver, .reload]
        case .vanished: [.saveAgain]
        case .reloaded, .savedOver, .copyKept, .draftRescued: [.dismiss]
        }
    }

    public var tone: NoticeTone {
        switch self {
        case .reloaded, .savedOver, .copyKept, .draftRescued: .warning
        case .saveFailed, .refused, .backupFailed, .saveOverRefused, .vanished: .error
        }
    }

    var keptCopies: [String] {
        switch self {
        case .reloaded(let backups, _), .savedOver(let backups, _), .copyKept(let backups, _): backups
        default: []
        }
    }

    var typingCopies: [String] {
        switch self {
        case .reloaded(_, let typing), .savedOver(_, let typing), .copyKept(_, let typing): typing
        default: []
        }
    }

    private static func typingSentence(_ copies: [String]) -> String {
        copies.isEmpty ? "" : " The element you were typing in is gone, and your text is in \(names(copies))."
    }

    private static func names(_ paths: [String]) -> String {
        paths.map { ($0 as NSString).lastPathComponent }.joined(separator: ", ")
    }
}
