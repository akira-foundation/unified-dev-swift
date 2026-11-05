import Foundation

public struct CanvasComment: Codable, Sendable, Hashable, Identifiable {
    public enum State: String, Codable, Sendable, Hashable {
        case queued, working, resolved, declined, unanswered
    }

    public var id: CanvasCommentID
    public var anchor: CanvasPoint
    public var frameID: CanvasFrameID?
    public var elementID: CanvasElementID?
    public var text: String
    public var state: State
    public var response: String?
    public var deliveryID: DeliveryID?
    public var createdAt: Date

    public init(
        id: CanvasCommentID = .new(),
        anchor: CanvasPoint,
        frameID: CanvasFrameID? = nil,
        elementID: CanvasElementID? = nil,
        text: String,
        state: State = .queued,
        response: String? = nil,
        deliveryID: DeliveryID? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.anchor = anchor
        self.frameID = frameID
        self.elementID = elementID
        self.text = text
        self.state = state
        self.response = response
        self.deliveryID = deliveryID
        self.createdAt = createdAt
    }
}
