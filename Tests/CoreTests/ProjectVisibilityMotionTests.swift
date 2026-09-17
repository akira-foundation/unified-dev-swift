import Testing
@testable import Core

@Suite struct ProjectVisibilityMotionTests {
    @Test func hidingWithTheHiddenOnesShownIsAContrastChangeAndNothingMoves() {
        let motion = ProjectVisibilityMotion.hideGesture(showingHidden: true, reduceMotion: false)
        #expect(motion == .dim(seconds: ProjectVisibilityMotion.seconds))
        #expect(!motion.fadesArrivals)
    }

    @Test func hidingWithThemNotShownTakesTheRowOutAndClosesTheGap() {
        let motion = ProjectVisibilityMotion.hideGesture(showingHidden: false, reduceMotion: false)
        #expect(motion == .reflow(seconds: ProjectVisibilityMotion.seconds))
        #expect(motion.fadesArrivals)
    }

    @Test func theFilterSwitchIsAlwaysAReflow() {
        #expect(ProjectVisibilityMotion.filterToggle(reduceMotion: false)
            == .reflow(seconds: ProjectVisibilityMotion.seconds))
    }

    @Test func reduceMotionDropsAllThreeRatherThanSlowingThem() {
        #expect(ProjectVisibilityMotion.hideGesture(showingHidden: true, reduceMotion: true) == .instant)
        #expect(ProjectVisibilityMotion.hideGesture(showingHidden: false, reduceMotion: true) == .instant)
        #expect(ProjectVisibilityMotion.filterToggle(reduceMotion: true) == .instant)
        #expect(ProjectVisibilityMotion.instant.seconds == nil)
        #expect(!ProjectVisibilityMotion.instant.fadesArrivals)
    }

    @Test func everyCaseTakesTheSameLengthAsARowSettling() {
        #expect(ProjectVisibilityMotion.seconds == TranscriptMotion.arrival(reduceMotion: false)?.seconds)
    }
}
