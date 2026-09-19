import Foundation
import Testing
@testable import Core

@Suite("TabRenaming")
struct TabRenamingTests {
    private let chat = PaneContent.chat(SessionID(rawValue: "s-one"))
    private let tool = PaneContent.tool("t-one")

    @Test("a conversation always has a name to change")
    func chatRenames() {
        #expect(TabRenaming.canRename(chat, tabKind: nil))
    }

    @Test("a shell and a page carry a name somebody chose")
    func toolsRename() {
        #expect(TabRenaming.canRename(tool, tabKind: .terminal))
        #expect(TabRenaming.canRename(tool, tabKind: .browser))
    }

    @Test("the review and the notes have no name of their own")
    func theFixedTitles() {
        #expect(!TabRenaming.canRename(tool, tabKind: .review))
        #expect(!TabRenaming.canRename(tool, tabKind: .notes))
    }

    @Test("a tab that is no longer open cannot be renamed")
    func missingTab() {
        #expect(!TabRenaming.canRename(tool, tabKind: nil))
    }

    @Test("every kind is decided, so a new one cannot arrive renameable by default")
    func everyKindIsAnswered() {
        let renameable = CenterTabKind.allCases.filter { TabRenaming.canRename(tool, tabKind: $0) }
        #expect(Set(renameable) == [.terminal, .browser])
    }

    @Test("a rename stays open only while its tab is in the strip")
    func openFieldFollowsTheStrip() {
        #expect(TabRenaming.openField("t-one", among: [chat, tool]) == "t-one")
        #expect(TabRenaming.openField("s-one", among: [chat]) == "s-one")
        #expect(TabRenaming.openField("t-one", among: [chat]) == nil)
        #expect(TabRenaming.openField(nil, among: [chat, tool]) == nil)
        #expect(TabRenaming.openField("t-one", among: []) == nil)
    }
}
