import Foundation

public enum AppRequest {
    public struct SentTurn: Sendable, Equatable {
        public var text: String
        public var isAppRequest: Bool

        public init(text: String, isAppRequest: Bool) {
            self.text = text
            self.isAppRequest = isAppRequest
        }
    }

    public static let unconfirmedSentence =
        "Unified Dev could not confirm that its request reached the agent. Send it again only if the agent did not answer."

    public static let sentBy = "unified_dev"

    private static let eventMarker = Data("\"app_request\"".utf8)

    public static func delivery(
        to sessionID: SessionID, text: String, interactionMode: InteractionMode?
    ) -> Delivery {
        var delivery = Delivery(targetSessionID: sessionID, kind: .report, crew: .appRequest(text))
        delivery.interactionMode = interactionMode
        return delivery
    }

    public static func isHidden(kind: MessageKind, payload: Data) -> Bool {
        sentText(kind: kind, payload: payload) != nil
    }

    public static func isHidden(_ delivery: Delivery) -> Bool {
        delivery.crewMessage?.event == .appRequest
    }

    public static func isStuck(_ delivery: Delivery) -> Bool {
        delivery.state == .uncertain || (delivery.state == .pending && delivery.deliveredSeq != nil)
    }

    public static func isQueued(_ text: String, in pending: [Delivery]) -> Bool {
        pending.contains { isHidden($0) && $0.sent == text }
    }

    public static func sentText(kind: MessageKind, payload: Data) -> String? {
        guard kind == .crew, payload.range(of: eventMarker) != nil,
              let crew = CrewMessage.decode(payload), crew.event == .appRequest else { return nil }
        return crew.sent
    }

    public static func sentTurn(of delivery: Delivery) -> SentTurn {
        isHidden(delivery)
            ? SentTurn(text: delivery.sent, isAppRequest: true)
            : SentTurn(text: delivery.body, isAppRequest: false)
    }

    public static func lastSentTurn(
        in rows: some BidirectionalCollection<(kind: MessageKind, payload: Data)>
    ) -> SentTurn? {
        for row in rows.reversed() {
            if row.kind == .user {
                return UserTurnPayload.text(from: row.payload).map { SentTurn(text: $0, isAppRequest: false) }
            }
            if let text = sentText(kind: row.kind, payload: row.payload) {
                return SentTurn(text: text, isAppRequest: true)
            }
        }
        return nil
    }
}
