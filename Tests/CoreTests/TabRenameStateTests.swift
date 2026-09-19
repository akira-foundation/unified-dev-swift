import Testing
@testable import Core

@Suite("TabRenameState")
struct TabRenameStateTests {
    private let workspace = WorkspaceID("w-one")
    private let other = WorkspaceID("w-two")
    private let entries: [PaneContent] = [.chat(SessionID(rawValue: "s-one")), .tool("t-one")]

    @Test("a rename begun on a tab is open on that tab and no other workspace")
    func beginOpensTheField() {
        var state = TabRenameState()
        state.begin("t-one", in: workspace)
        #expect(state.id(in: workspace, among: entries) == "t-one")
        #expect(state.id(in: other, among: entries) == nil)
    }

    @Test("what was typed survives the strip being drawn again")
    func draftSurvives() {
        var state = TabRenameState()
        state.begin("t-one", in: workspace)
        state.keepDraft("Build log", in: workspace)
        #expect(state.draft(in: workspace) == "Build log")
        #expect(state.draft(in: other) == nil)
    }

    @Test("a new rename starts from the title, not from the last one's draft")
    func beginClearsTheDraft() {
        var state = TabRenameState()
        state.begin("t-one", in: workspace)
        state.keepDraft("Build log", in: workspace)
        state.begin("s-one", in: workspace)
        #expect(state.draft(in: workspace) == nil)
    }

    @Test("ending a rename forgets the field and its draft")
    func endForgets() {
        var state = TabRenameState()
        state.begin("t-one", in: workspace)
        state.keepDraft("Build log", in: workspace)
        state.end(in: workspace)
        #expect(state.id(in: workspace, among: entries) == nil)
        #expect(state.draft(in: workspace) == nil)
    }

    @Test("typing with no rename open keeps nothing")
    func draftNeedsARename() {
        var state = TabRenameState()
        state.keepDraft("stray", in: workspace)
        #expect(state.draft(in: workspace) == nil)
    }
}
