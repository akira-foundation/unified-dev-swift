import Testing
@testable import Core

@Suite("Browser toolbar page actions")
struct BrowserToolbarPageActionsTests {
    private static func toolbar(address: String = "http://localhost:3100/", isCapturing: Bool = false) -> BrowserToolbar {
        BrowserToolbar(
            page: BrowserTabTitle.BrowserPage(address: address, title: ""),
            isCapturing: isCapturing
        )
    }

    @Test("Comment can be pressed on a page with nothing being captured, and is not lit")
    func commentOnAPage() {
        let comment = Self.toolbar().comment(isReviewing: false, isSaving: false)
        #expect(comment.isEnabled)
        #expect(!comment.isActive)
        #expect(comment.symbol == "text.bubble")
        #expect(comment.name == "Comment")
    }

    @Test("A pane with no page has nothing to comment on")
    func commentNeedsAPage() {
        #expect(!Self.toolbar(address: "").comment(isReviewing: false, isSaving: false).isEnabled)
    }

    @Test("Comment waits while a capture is in flight or a review is still being saved")
    func commentWaitsForCaptureAndSave() {
        #expect(!Self.toolbar(isCapturing: true).comment(isReviewing: false, isSaving: false).isEnabled)
        #expect(!Self.toolbar().comment(isReviewing: false, isSaving: true).isEnabled)
    }

    @Test("While reviewing, Comment turns into a lit Done that stays pressable")
    func reviewingLightsDone() {
        let done = Self.toolbar(isCapturing: true).comment(isReviewing: true, isSaving: false)
        #expect(done.isEnabled)
        #expect(done.isActive)
        #expect(done.symbol == "checkmark")
        #expect(done.name == "Done")
    }

    @Test("A review being saved cannot be finished twice, and is not lit while it waits")
    func savingHoldsDone() {
        let saving = Self.toolbar().comment(isReviewing: true, isSaving: true)
        #expect(!saving.isEnabled)
        #expect(!saving.isActive)
    }

    @Test("The viewport button is lit exactly while the page is shown at a set size")
    func viewportLightsWhileSized() {
        var viewport = BrowserViewport()
        #expect(!BrowserToolbar.viewport(viewport).isActive)
        #expect(BrowserToolbar.viewport(viewport).isEnabled)

        viewport.isEnabled = true
        let sized = BrowserToolbar.viewport(viewport)
        #expect(sized.isActive)
        #expect(sized.help.contains("\(viewport.width) × \(viewport.height)"))
    }

    @Test("Full size can be pressed only when there is a set size to leave")
    func fullSizeNeedsASetSize() {
        var viewport = BrowserViewport()
        #expect(!BrowserToolbar.fullSize(viewport).isEnabled)
        viewport.isEnabled = true
        #expect(BrowserToolbar.fullSize(viewport).isEnabled)
    }

    @Test("None of the page actions uses its name as its tooltip")
    func tooltipsSayMore() {
        let toolbar = Self.toolbar()
        let controls = [
            toolbar.comment(isReviewing: false, isSaving: false),
            toolbar.comment(isReviewing: true, isSaving: false),
            BrowserToolbar.viewport(BrowserViewport()),
            BrowserToolbar.fullSize(BrowserViewport()),
        ]
        for control in controls {
            #expect(control.help != control.name)
            #expect(!control.help.isEmpty)
        }
    }
}
