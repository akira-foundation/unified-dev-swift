import Testing
import Foundation
@testable import Core

@Suite("Setup run offer")
struct SetupRunOfferTests {
    @Test("a repository with no setup script is offered nothing at all")
    func noScriptNoItem() {
        #expect(SetupRunOffer.offer(hasSetupScript: false, hasRunSetup: false, isRunning: false) == nil)
        #expect(SetupRunOffer.offer(hasSetupScript: false, hasRunSetup: true, isRunning: false) == nil)
    }

    @Test("a run in flight greys the item rather than removing it")
    func aRunGreysRatherThanHides() throws {
        let offer = try #require(
            SetupRunOffer.offer(hasSetupScript: true, hasRunSetup: true, isRunning: true)
        )
        #expect(offer.isEnabled == false)
        #expect(offer.title == "Run Setup Again")
    }

    @Test("the title says again only when there was a first time")
    func theTitleSaysAgainOnlyAfterARun() throws {
        let first = try #require(
            SetupRunOffer.offer(hasSetupScript: true, hasRunSetup: false, isRunning: false)
        )
        #expect(first.title == "Run Setup")

        let again = try #require(
            SetupRunOffer.offer(hasSetupScript: true, hasRunSetup: true, isRunning: false)
        )
        #expect(again.title == "Run Setup Again")
    }

    @Test("nothing but a run in flight can disable an item that is offered")
    func onlyARunDisables() throws {
        for hasRunSetup in [true, false] {
            let offer = try #require(
                SetupRunOffer.offer(
                    hasSetupScript: true, hasRunSetup: hasRunSetup, isRunning: false
                )
            )
            #expect(offer.isEnabled)
        }
    }
}
