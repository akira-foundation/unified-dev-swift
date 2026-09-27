import Testing
@testable import Core

@Suite("The work mode row")
struct ComposerWorkModeRowTests {
    @Test("With planning available the row offers the choice", arguments: [InteractionMode.build, .plan])
    func availableOffersTheChoice(mode: InteractionMode) {
        #expect(ComposerWorkModeRow(isPlanningAvailable: true, interactionMode: mode) == .choice)
    }

    @Test("Without planning, a conversation left in Plan is offered a way back to Build")
    func strandedInPlan() {
        #expect(ComposerWorkModeRow(isPlanningAvailable: false, interactionMode: .plan) == .offerBuild)
    }

    @Test("Without planning, a conversation in Build only says so")
    func alreadyInBuild() {
        #expect(ComposerWorkModeRow(isPlanningAvailable: false, interactionMode: .build) == .build)
    }
}
