import Foundation

public struct AgentSwitchWorkMode: Sendable, Equatable {
    public enum PlanRoute: Sendable, Equatable {
        case perTurn
        case perChat
        case none

        public static func of(_ agent: AgentKind, codexPlanningIsAvailable: Bool) -> PlanRoute {
            guard InteractionMode.supports(agent) else { return .perChat }
            return codexPlanningIsAvailable ? .perTurn : .none
        }

        public static func read(_ agent: AgentKind, from store: Store) async -> PlanRoute {
            let unavailable = try? await store.setting(CodexPlanningCapability.unavailableKey)
            return of(agent, codexPlanningIsAvailable: unavailable != "1")
        }
    }

    public var permissionMode: PermissionMode
    public var interactionMode: InteractionMode
    public var rewritten: [DeliveryID: InteractionMode]
    public var returned: [DeliveryID]
    public var notice: String?
    public var noticeTone = NoticeTone.information

    public static func decide(
        from source: Session, to controls: ComposerControls, queue: [Delivery], route: PlanRoute
    ) -> AgentSwitchWorkMode {
        let agent = controls.agentKind
        let underPlanPermission = source.permissionMode == .plan
        let chatWasPlanning = underPlanPermission || source.interactionMode == .plan
        let isUntouched = controls.permissionMode == source.permissionMode.nearest(on: agent)
            && controls.interactionMode == source.interactionMode.nearest(on: agent)
        let moving = queue.filter { $0.state == .pending && $0.interactionMode != nil }
        let wantsPlan = { (delivery: Delivery) in underPlanPermission || delivery.interactionMode == .plan }
        let firstWants = moving.first { !AppRequest.isHidden($0) }.map(wantsPlan)
        let stuckPlans = moving.filter { wantsPlan($0) && !PendingMessageReturn.canReturn($0) }
        let chatChoice = switch (isUntouched, route) {
        case (false, _): controls.permissionMode == .plan || controls.interactionMode == .plan
        case (true, .perChat): chatWasPlanning || firstWants == true
        case (true, .perTurn), (true, .none): firstWants ?? chatWasPlanning
        }
        let heldInPlan = route == .perChat && !stuckPlans.isEmpty && !chatChoice
        let chatWants = chatChoice || heldInPlan

        var rewritten: [DeliveryID: InteractionMode] = [:]
        var returned: [DeliveryID] = []
        for delivery in moving {
            let wants = wantsPlan(delivery)
            switch route {
            case .perTurn:
                rewritten[delivery.id] = wants ? .plan : .build
            case .perChat where wants == chatWants, .none where !wants:
                rewritten[delivery.id] = .build
            case .none where !PendingMessageReturn.canReturn(delivery):
                rewritten[delivery.id] = .plan
            case .perChat, .none:
                if PendingMessageReturn.canReturn(delivery) { returned.append(delivery.id) }
            }
        }

        let lostPlan = route == .none && (isUntouched ? chatWasPlanning : chatWants)
        let refused = route == .none ? stuckPlans.filter { !AppRequest.isHidden($0) }.count : 0
        let told = Told(
            returned: returned.count, refused: refused, lostPlan: lostPlan,
            gainedPlan: route != .none && isUntouched && chatChoice && !chatWasPlanning,
            heldInPlan: heldInPlan
        )
        return AgentSwitchWorkMode(
            permissionMode: route == .perChat && chatWants ? .plan : controls.permissionMode,
            interactionMode: route == .perTurn && chatWants ? .plan : .build,
            rewritten: rewritten,
            returned: returned,
            notice: notice(told, route: route, agent: agent),
            noticeTone: lostPlan || refused > 0 ? .warning : .information
        )
    }

    private struct Told {
        let returned: Int
        let refused: Int
        let lostPlan: Bool
        let gainedPlan: Bool
        let heldInPlan: Bool
    }

    private static func notice(_ told: Told, route: PlanRoute, agent: AgentKind) -> String? {
        let reason = route == .none
            ? "This \(agent.label) version does not support Plan"
            : "\(agent.label) runs one work mode per chat"
        var sentences: [String] = []
        if told.returned == 1 {
            sentences.append("A queued message is back in the composer. \(reason), so it could not go as sent.")
        }
        if told.returned > 1 {
            sentences.append("Your queued messages are back in the composer. \(reason), so they could not go as sent.")
        }
        if told.lostPlan {
            let saysWhy = told.returned == 0 && told.refused == 0
            sentences.append(saysWhy ? "This chat is now in Build. \(reason)." : "This chat is now in Build.")
        }
        if told.gainedPlan { sentences.append("This chat is now in Plan, because its next queued message was sent in Plan.") }
        if told.heldInPlan {
            sentences.append("This chat is now in Plan, because a queued message that cannot go back to the composer was sent in Plan.")
        }
        if told.refused == 1 {
            sentences.append(
                "A queued message with attachments or review comments was sent in Plan. "
                    + "\(reason), so \(agent.label) will refuse it until you remove it from the queue."
            )
        }
        if told.refused > 1 {
            sentences.append(
                "Queued messages with attachments or review comments were sent in Plan. "
                    + "\(reason), so \(agent.label) will refuse them until you remove them from the queue."
            )
        }
        return sentences.isEmpty ? nil : sentences.joined(separator: " ")
    }

    public func applied(to controls: ComposerControls) -> ComposerControls {
        var applied = controls
        applied.permissionMode = permissionMode
        applied.interactionMode = interactionMode
        return applied
    }

    public func returning(from queue: [Delivery]) -> [Delivery] {
        queue.filter { returned.contains($0.id) }
    }
}
