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
    case vanished
    case reloaded(backup: String)

    public var title: String {
        switch self {
        case .saveFailed: "This canvas is not saved"
        case .refused: "Saving is paused"
        case .backupFailed: "The file changed, and it was not reloaded"
        case .vanished: "This canvas is no longer on disk"
        case .reloaded: "The file changed on disk, so it was reloaded"
        }
    }

    public var message: String {
        switch self {
        case .saveFailed(let reason):
            "Your edits are safe in this tab. Saving will be tried again on your next edit. \(reason)"
        case .refused(let reason):
            "Your edits are safe in this tab, and the file is left as it is. \(reason)"
        case .backupFailed(let reason):
            "A copy of your version could not be written, so nothing was replaced and saving is paused. \(reason)"
        case .vanished:
            "Saving is paused, and your edits are safe in this tab. The file will not be recreated unless you save it again."
        case .reloaded(let backup):
            "Your previous version is kept beside it, in \((backup as NSString).lastPathComponent)."
        }
    }

    public var actions: [CanvasDiskWarningAction] {
        switch self {
        case .saveFailed: [.tryAgain]
        case .refused, .backupFailed: [.saveOver, .reload]
        case .vanished: [.saveAgain]
        case .reloaded: [.dismiss]
        }
    }

    public var tone: NoticeTone {
        if case .reloaded = self { return .warning }
        return .error
    }
}
