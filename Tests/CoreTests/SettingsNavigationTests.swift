import Testing
@testable import Core

@Suite("Settings navigation")
struct SettingsNavigationTests {
    @Test("choosing a page remembers where you were and forgets where you had gone")
    func select() {
        var navigation = SettingsNavigation(current: "general")
        navigation.select("agents")
        navigation.select("terminal")
        navigation.goBack()
        navigation.select("prompts")
        #expect(navigation.current == "prompts")
        #expect(navigation.history == ["general", "agents"])
        #expect(!navigation.canGoForward)
    }

    @Test("choosing the page already shown changes nothing")
    func sameAgain() {
        var navigation = SettingsNavigation(current: "general")
        navigation.select("general")
        #expect(!navigation.canGoBack)
    }

    @Test("back and forward walk the same pages both ways, and stop at either end")
    func backAndForward() {
        var navigation = SettingsNavigation(current: "general")
        navigation.select("agents")
        navigation.select("terminal")
        navigation.goBack()
        navigation.goBack()
        #expect(navigation.current == "general")
        navigation.goBack()
        #expect(navigation.current == "general")
        navigation.goForward()
        navigation.goForward()
        #expect(navigation.current == "terminal")
        #expect(!navigation.canGoForward)
        #expect(navigation.canGoBack)
    }
}

@Suite("Settings sidebar search")
struct SettingsSidebarSearchTests {
    private let sections = [
        SettingsSidebarSection("Unified Dev", pages: ["General", "Menu Bar"]),
        SettingsSidebarSection("Terminal & connections", pages: ["Terminal", "Command Line"]),
    ]

    @Test("an empty or blank search shows every section")
    func blank() {
        #expect(SettingsSidebarSection.matching(sections, query: "  ", title: { $0 }) == sections)
    }

    @Test("a search keeps matching pages under their heading and drops sections left empty")
    func matching() {
        let found = SettingsSidebarSection.matching(sections, query: "line", title: { $0 })
        #expect(found == [SettingsSidebarSection("Terminal & connections", pages: ["Command Line"])])
    }

    @Test("a search ignores case")
    func caseInsensitive() {
        let found = SettingsSidebarSection.matching(sections, query: "MENU", title: { $0 })
        #expect(found.map(\.pages) == [["Menu Bar"]])
    }
}
