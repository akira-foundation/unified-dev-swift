import Foundation

public struct Delivery: Identifiable, Sendable, Hashable {
    public enum Kind: String, Sendable, Hashable, CaseIterable {
        case owner
        case message
        case report
    }

    public enum State: String, Sendable, Hashable, Codable {
        case pending, claimed, accepted, uncertain
    }

    public var state: State
    public var interactionMode: InteractionMode?
    public var providerTurnID: String?
    public var id: DeliveryID
    public var targetSessionID: SessionID
    public var sourceWorkspaceID: WorkspaceID?
    public var kind: Kind
    public var verdict: String?
    public var body: String
    public var crewPayload: Data?
    public var createdAt: Date
    public var deliveredAt: Date?
    public var deliveredSeq: Int?

    public init(
        id: DeliveryID = .new(),
        targetSessionID: SessionID,
        sourceWorkspaceID: WorkspaceID? = nil,
        kind: Kind = .owner,
        verdict: String? = nil,
        body: String,
        crewPayload: Data? = nil,
        createdAt: Date = Date(),
        deliveredAt: Date? = nil,
        deliveredSeq: Int? = nil,
        state: State? = nil,
        interactionMode: InteractionMode? = nil,
        providerTurnID: String? = nil
    ) {
        self.state = state ?? (deliveredAt == nil ? .pending : .accepted)
        self.interactionMode = interactionMode
        self.providerTurnID = providerTurnID
        self.id = id
        self.targetSessionID = targetSessionID
        self.sourceWorkspaceID = sourceWorkspaceID
        self.kind = kind
        self.verdict = verdict
        self.body = body
        self.crewPayload = crewPayload
        self.createdAt = createdAt
        self.deliveredAt = deliveredAt
        self.deliveredSeq = deliveredSeq
    }

    public init(
        id: DeliveryID = .new(),
        targetSessionID: SessionID,
        sourceWorkspaceID: WorkspaceID? = nil,
        kind: Kind,
        verdict: String? = nil,
        crew message: CrewMessage,
        createdAt: Date = Date()
    ) {
        self.init(
            id: id,
            targetSessionID: targetSessionID,
            sourceWorkspaceID: sourceWorkspaceID,
            kind: kind,
            verdict: verdict,
            body: message.text,
            crewPayload: try? message.payload(),
            createdAt: createdAt
        )
    }

    public var crewMessage: CrewMessage? { crewPayload.flatMap(CrewMessage.decode) }

    public var sent: String { crewMessage?.sent ?? body }

    public var isPending: Bool { state == .pending || state == .uncertain }

    public static func deliverable(
        from pending: [Delivery], hold: DeliveryHold, on agent: AgentKind
    ) -> [Delivery] {
        guard hold.allowsDelivery(on: agent) else { return [] }
        let ready = Array(pending.prefix { $0.state == .pending })
        guard agent.acceptsMidTurnMessage else { return Array(ready.prefix(1)) }
        return ready
    }

    public static func next(
        from pending: [Delivery], hold: DeliveryHold, on agent: AgentKind
    ) -> Delivery? {
        deliverable(from: pending, hold: hold, on: agent).first
    }

    public static func goesImmediately(
        behind pending: [Delivery], hold: DeliveryHold, on agent: AgentKind
    ) -> Bool {
        guard hold.allowsDelivery(on: agent) else { return false }
        return pending.isEmpty
    }
}
