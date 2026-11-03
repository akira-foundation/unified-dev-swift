import Foundation

public struct CanvasCommentTurn: Sendable, Equatable {
    public let deliveryID: DeliveryID
    public let path: String

    public init(deliveryID: DeliveryID, path: String) {
        self.deliveryID = deliveryID
        self.path = path
    }
}

public struct CanvasCommentTurns: Sendable, Equatable {
    private var bySession: [SessionID: CanvasCommentTurn] = [:]

    public init() {}

    public mutating func start(_ turn: CanvasCommentTurn, in session: SessionID) -> CanvasCommentTurn? {
        bySession.updateValue(turn, forKey: session)
    }

    public mutating func end(in session: SessionID) -> CanvasCommentTurn? {
        bySession.removeValue(forKey: session)
    }

    public mutating func end(_ delivery: DeliveryID, in session: SessionID) {
        guard bySession[session]?.deliveryID == delivery else { return }
        bySession[session] = nil
    }

    public func deliveries(inDocument path: String) -> Set<DeliveryID> {
        Set(bySession.values.filter { $0.path == path }.map(\.deliveryID))
    }
}
