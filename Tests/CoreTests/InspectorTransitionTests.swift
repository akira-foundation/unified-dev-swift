import Testing
@testable import Core

@Suite("The inspector's transition")
struct InspectorTransitionTests {
    @Test func slidesWhenOnlyTheInspectorIsChanging() {
        #expect(InspectorTransition.isAnimated(motionAllowed: true, contentIsChanging: false))
    }

    @Test func doesNotSlideWhileThePaneIsBeingSwapped() {
        #expect(!InspectorTransition.isAnimated(motionAllowed: true, contentIsChanging: true))
    }

    @Test func reducedMotionWinsEitherWay() {
        #expect(!InspectorTransition.isAnimated(motionAllowed: false, contentIsChanging: false))
        #expect(!InspectorTransition.isAnimated(motionAllowed: false, contentIsChanging: true))
    }
}
