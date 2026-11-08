import Foundation

extension SoftwareUpdate {
    public static let offerHeldSinceKey = "updates.offerHeldSince"

    public static let offerHoldLimit: TimeInterval = 28_800

    public static let heldOfferRecheckInterval: TimeInterval = 60

    public enum OfferMoment: Equatable, Sendable {
        case present
        case hold
    }

    public static func offerMoment(
        runningCount: Int,
        canShowAlert: Bool,
        ownerJustReturned: Bool,
        heldSince: Date?,
        now: Date
    ) -> OfferMoment {
        guard canShowAlert else { return .hold }
        guard runningCount > 0, !ownerJustReturned else { return .present }
        guard let heldSince else { return .hold }
        let held = now.timeIntervalSince(heldSince)
        return held < 0 || held >= offerHoldLimit ? .present : .hold
    }

    public static func holdStart(recorded: Date?, now: Date) -> Date {
        recorded ?? now
    }

    public static func isBackgroundCheckDue(lastCheckedAt: Date?, heldOfferCheckedAt: Date?, now: Date) -> Bool {
        isDue(lastCheckedAt: heldOfferCheckedAt ?? lastCheckedAt, now: now)
    }

    public static func recheckDelay(holdingOffer: Bool) -> TimeInterval {
        holdingOffer ? heldOfferRecheckInterval : recheckInterval
    }
}
