import Foundation

public enum CanvasDiskStep: Sendable, Equatable {
    case read
    case save(Data, expecting: [Data]?)
    case backup(Data)
}

public enum CanvasDiskResult: Sendable, Equatable {
    case read(Data?)
    case unreadable(String)
    case written(Data)
    case savedOver(Data, backup: String)
    case saveOverRefused(String)
    case writeFailed(String)
    case outsideChange
    case backedUp(String)
    case backupFailed(String)
}
