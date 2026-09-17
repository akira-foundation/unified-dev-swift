import Testing
@testable import Core

@Suite("The composer's hold on the keyboard")
struct ComposerFocusTests {
    @Test func takesTheKeyboardWhenSomethingElseAsksItTo() {
        #expect(ComposerFocus.shouldTakeKeyboard(
            wantsFocus: true, holdsKeyboard: false, isReportingChange: false
        ))
    }

    @Test func leavesItAloneWhileTheViewsOwnResignIsStillInFlight() {
        #expect(!ComposerFocus.shouldTakeKeyboard(
            wantsFocus: true, holdsKeyboard: false, isReportingChange: true
        ))
    }

    @Test func doesNothingWhenItAlreadyHasIt() {
        #expect(!ComposerFocus.shouldTakeKeyboard(
            wantsFocus: true, holdsKeyboard: true, isReportingChange: false
        ))
        #expect(!ComposerFocus.shouldGiveUpKeyboard(wantsFocus: true, holdsKeyboard: true))
    }

    @Test func givesItUpWhenTheBindingSaysSo() {
        #expect(ComposerFocus.shouldGiveUpKeyboard(wantsFocus: false, holdsKeyboard: true))
    }

    @Test func hasNothingToGiveUpWhenItNeverHadIt() {
        #expect(!ComposerFocus.shouldGiveUpKeyboard(wantsFocus: false, holdsKeyboard: false))
    }

    @Test func neverBothAtOnce() {
        for wants in [true, false] {
            for holds in [true, false] {
                for reporting in [true, false] {
                    let takes = ComposerFocus.shouldTakeKeyboard(
                        wantsFocus: wants, holdsKeyboard: holds, isReportingChange: reporting
                    )
                    let gives = ComposerFocus.shouldGiveUpKeyboard(
                        wantsFocus: wants, holdsKeyboard: holds
                    )
                    #expect(!(takes && gives))
                }
            }
        }
    }
}
