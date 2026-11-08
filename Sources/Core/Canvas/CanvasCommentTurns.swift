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
    private var starting: Set<SessionID> = []

    public init() {}

    public mutating func start(_ turn: CanvasCommentTurn, in session: SessionID) -> CanvasCommentTurn? {
        starting.insert(session)
        return bySession.updateValue(turn, forKey: session)
    }

    public mutating func began(_ delivery: DeliveryID, in session: SessionID) {
        guard bySession[session]?.deliveryID == delivery else { return }
        starting.remove(session)
    }

    public mutating func end(in session: SessionID) -> CanvasCommentTurn? {
        guard !starting.contains(session) else { return nil }
        return bySession.removeValue(forKey: session)
    }

    public mutating func end(_ delivery: DeliveryID, in session: SessionID) {
        guard bySession[session]?.deliveryID == delivery else { return }
        bySession[session] = nil
        starting.remove(session)
    }

    public mutating func stop(in session: SessionID) -> CanvasCommentTurn? {
        starting.remove(session)
        return bySession.removeValue(forKey: session)
    }

    public func deliveries(inDocument path: String) -> Set<DeliveryID> {
        Set(bySession.values.filter { $0.path == path }.map(\.deliveryID))
    }
}
