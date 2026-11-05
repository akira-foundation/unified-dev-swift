import Foundation

public enum ChatStop: Sendable, Equatable {
    case notStopped
    case byOwner
    case byRewind

    public var holdsMessages: Bool { self != .notStopped }

    public var holdsCanvasComments: Bool { self == .byOwner }

    public var afterRewind: ChatStop { self == .byOwner ? .byOwner : .byRewind }

    public func releasedForCanvasComments(pending: [Delivery]) -> ChatStop? {
        guard !holdsCanvasComments, Delivery.holdsOnlyCanvasComments(pending) else { return nil }
        return .notStopped
    }
}
