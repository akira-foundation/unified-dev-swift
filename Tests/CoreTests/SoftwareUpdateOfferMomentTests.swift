import Foundation
import Testing
@testable import Core

@Suite("When a release found in the background is offered")
struct SoftwareUpdateOfferMomentTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func moment(
        running: Int,
        canShowAlert: Bool = true,
        returned: Bool = false,
        heldFor: TimeInterval? = nil
    ) -> SoftwareUpdate.OfferMoment {
        SoftwareUpdate.offerMoment(
            runningCount: running,
            canShowAlert: canShowAlert,
            ownerJustReturned: returned,
            heldSince: heldFor.map { now.addingTimeInterval(-$0) },
            now: now
        )
    }

    @Test("With no agent running there is nothing to wait for")
    func noAgentsPresents() {
        #expect(moment(running: 0) == .present)
    }

    @Test("A running agent holds a release that has only just been found")
    func runningAgentHolds() {
        #expect(moment(running: 1) == .hold)
        #expect(moment(running: 3, heldFor: 60) == .hold)
    }

    @Test("The owner coming back to the app is a moment between tasks, agents or not")
    func returningPresents() {
        #expect(moment(running: 2, returned: true) == .present)
    }

    @Test("A hold ends at its limit however many agents never stop")
    func holdIsBounded() {
        let limit = SoftwareUpdate.offerHoldLimit

        #expect(limit == 8 * 3_600)
        #expect(moment(running: 5, heldFor: 0) == .hold)
        #expect(moment(running: 5, heldFor: limit - 1) == .hold)
        #expect(moment(running: 5, heldFor: limit) == .present)
    }

    @Test("An alert that cannot be shown waits, whatever else says it could go up")
    func unshowableAlertHolds() {
        #expect(moment(running: 0, canShowAlert: false) == .hold)
        #expect(moment(running: 2, canShowAlert: false, returned: true) == .hold)
        #expect(moment(running: 2, canShowAlert: false, heldFor: SoftwareUpdate.offerHoldLimit) == .hold)
    }

    @Test("A hold keeps the moment it began, so relaunching does not restart the limit")
    func holdStartSurvivesRelaunch() {
        let began = now.addingTimeInterval(-3_600)

        #expect(SoftwareUpdate.holdStart(recorded: began, now: now) == began)
        #expect(SoftwareUpdate.holdStart(recorded: nil, now: now) == now)
    }

    @Test("A clock set back cannot make a hold last for ever")
    func clockSetBackEndsTheHold() {
        #expect(moment(running: 1, heldFor: -3_600) == .present)
    }

    @Test("A background check is due by the clock alone, and agents are not part of it")
    func backgroundCheckIgnoresAgents() {
        #expect(SoftwareUpdate.isBackgroundCheckDue(lastCheckedAt: nil, heldOfferCheckedAt: nil, now: now))
        #expect(!SoftwareUpdate.isBackgroundCheckDue(
            lastCheckedAt: now.addingTimeInterval(-60), heldOfferCheckedAt: nil, now: now
        ))
    }

    @Test("A held offer is checked again a day after it was found, so it cannot go stale")
    func heldOfferIsRefreshedDaily() {
        let foundJustNow = now.addingTimeInterval(-60)
        let foundYesterday = now.addingTimeInterval(-SoftwareUpdate.checkInterval)
        let checkedLastWeek = now.addingTimeInterval(-7 * SoftwareUpdate.checkInterval)

        #expect(!SoftwareUpdate.isBackgroundCheckDue(
            lastCheckedAt: checkedLastWeek, heldOfferCheckedAt: foundJustNow, now: now
        ))
        #expect(!SoftwareUpdate.isBackgroundCheckDue(lastCheckedAt: nil, heldOfferCheckedAt: foundJustNow, now: now))
        #expect(SoftwareUpdate.isBackgroundCheckDue(lastCheckedAt: nil, heldOfferCheckedAt: foundYesterday, now: now))
    }

    @Test("A held offer is looked at far more often than the release feed")
    func heldOfferIsLookedAtSooner() {
        #expect(SoftwareUpdate.recheckDelay(holdingOffer: false) == SoftwareUpdate.recheckInterval)
        #expect(SoftwareUpdate.recheckDelay(holdingOffer: true) == SoftwareUpdate.heldOfferRecheckInterval)
        #expect(SoftwareUpdate.heldOfferRecheckInterval == 60)
    }

    @Test("The promise on the setting no longer says a check waits for agents")
    func settingDoesNotPromiseToWait() {
        #expect(!SoftwareUpdate.settingDetail.contains("never while"))
        #expect(SoftwareUpdate.settingDetail.contains("Nothing is installed until you say so."))
    }
}
