import Foundation

public enum ChatStop: Sendable, Equatable {
    case notStopped
    case byOwner
    case byOwnerForCanvasComments
    case byRewind

    public var holdsMessages: Bool { self == .byOwner || self == .byRewind }

    public var holdsCanvasComments: Bool { self == .byOwner || self == .byOwnerForCanvasComments }

    public var afterRewind: ChatStop { holdsCanvasComments ? .byOwner : .byRewind }

    public var afterAppRequest: ChatStop { holdsCanvasComments ? .byOwnerForCanvasComments : .notStopped }

    public func afterDelivering(_ delivery: Delivery) -> ChatStop {
        AppRequest.isHidden(delivery) ? afterAppRequest : .notStopped
    }

    public func releasedForCanvasComments(pending: [Delivery]) -> ChatStop? {
        guard !holdsCanvasComments, Delivery.holdsOnlyCanvasComments(pending) else { return nil }
        return .notStopped
    }
}
