import Testing
@testable import Core

@Suite("Sidebar grouping")
struct SidebarGroupingTests {
    @Test("the pane is grouped by project unless the owner chose status")
    func defaultsToProjects() {
        #expect(SidebarGrouping.standard == .projects)
        #expect(SidebarGrouping.resolve("") == .projects)
        #expect(SidebarGrouping.resolve("byColour") == .projects)
        #expect(SidebarGrouping.resolve("projects") == .projects)
        #expect(SidebarGrouping.resolve("status") == .status)
    }

    @Test("the default leads the menu")
    func defaultLeads() {
        #expect(SidebarGrouping.allCases.first == SidebarGrouping.standard)
    }

    @Test("only the project shape can be reordered and draws project headers")
    func projectShapeOnly() {
        #expect(SidebarGrouping.projects.allowsReordering)
        #expect(!SidebarGrouping.status.allowsReordering)
        #expect(SidebarGrouping.projects.drawsProjectHeaders)
        #expect(!SidebarGrouping.status.drawsProjectHeaders)
    }

    @Test("the choice is kept under a key of its own")
    func storageKey() {
        #expect(SidebarGrouping.storageKey == "sidebar.grouping")
        #expect(SidebarGrouping.storageKey != ProjectVisibility.showsHiddenKey)
    }

    @Test("each shape has a title and a symbol for the menus")
    func titles() {
        #expect(SidebarGrouping.allCases.map(\.title) == ["Project", "Status"])
        #expect(SidebarGrouping.allCases.map(\.icon) == ["folder", "list.bullet.indent"])
    }
}
