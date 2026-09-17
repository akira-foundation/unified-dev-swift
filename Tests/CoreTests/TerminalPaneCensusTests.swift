import Foundation
import Testing
@testable import Core

@Suite("TerminalPaneCensus")
struct TerminalPaneCensusTests {
    private let workspace = WorkspaceID("w1")

    private func domain() -> (name: String, defaults: UserDefaults) {
        let name = "unifieddev.test.tabs.\(UUID().uuidString)"
        return (name, UserDefaults(suiteName: name)!)
    }

    private func clean(_ name: String) {
        UserDefaults.standard.removePersistentDomain(forName: name)
    }

    private func tabList(_ defaults: UserDefaults) {
        let json = #"""
        [{"id":"t1","workspaceID":"w1","kind":"terminal","title":"Terminal","url":"","path":""},
         {"id":"t2","workspaceID":"w1","kind":"browser","title":"Browser","url":"http://x","path":""},
         {"id":"t3","workspaceID":"w1","kind":"terminal","title":"Server","url":"","path":""}]
        """#
        defaults.set(json.data(using: .utf8), forKey: "center.tabs.w1")
    }

    @Test("only terminal tabs are counted")
    func terminalTabsOnly() {
        let (name, defaults) = domain()
        defer { clean(name) }
        tabList(defaults)

        #expect(TerminalPaneCensus.terminalTabs(of: workspace, in: defaults) == ["t1", "t3"])
    }

    @Test("a workspace with no tab list names no panes and is not in doubt")
    func noTabs() {
        let (name, defaults) = domain()
        defer { clean(name) }

        #expect(TerminalPaneCensus.terminalTabs(of: workspace, in: defaults) == [])
        #expect(TerminalPaneCensus.census(of: [workspace], in: defaults) == .init())
    }

    @Test("an unsplit tab is one pane named after the tab")
    func unsplitTab() {
        let (name, defaults) = domain()
        defer { clean(name) }

        #expect(TerminalPaneCensus.panes(ofTab: "t1", in: defaults) == ["t1"])
    }

    @Test("a split tab names every pane of its tree")
    func splitTab() throws {
        let (name, defaults) = domain()
        defer { clean(name) }
        var layout = SplitLayout(pane: "t1")
        layout.split("t1", axis: .horizontal, into: "x1")
        layout.split("x1", axis: .vertical, into: "x2")
        let value = try #require(layout.encoded)
        defaults.set(value, forKey: "terminal.split.t1")

        #expect(TerminalPaneCensus.panes(ofTab: "t1", in: defaults) == ["t1", "x1", "x2"])
    }

    @Test("the live set is every terminal tab of every workspace, expanded")
    func livePanes() throws {
        let (name, defaults) = domain()
        defer { clean(name) }
        tabList(defaults)
        var layout = SplitLayout(pane: "t1")
        layout.split("t1", axis: .horizontal, into: "x1")
        let value = try #require(layout.encoded)
        defaults.set(value, forKey: "terminal.split.t1")

        #expect(TerminalPaneCensus.census(of: [workspace], in: defaults).panes == ["t1", "x1", "t3"])
    }

    @Test("the stored tab record is read field for field as CenterTab writes it")
    func wireContract() {
        let (name, defaults) = domain()
        defer { clean(name) }

        let current = #"{"id":"t1","workspaceID":"w1","kind":"terminal","title":"Terminal","url":"","path":""}"#
        let legacy = #"{"id":"t2","workspaceID":"w1","kind":"terminal","title":"Server"}"#
        let folder = #"{"id":"t3","workspaceID":"w1","kind":"terminal","title":"css","directory":"/tmp/w/css"}"#
        defaults.set(Data("[\(current),\(legacy),\(folder)]".utf8), forKey: "center.tabs.w1")

        #expect(TerminalPaneCensus.terminalTabs(of: workspace, in: defaults) == ["t1", "t2", "t3"])
    }

    @Test("the keys the sweep reads are the keys the stores write")
    func keysArePinned() {
        #expect(TabDefaults.tabListKey(workspace) == "center.tabs.w1")
        #expect(TabDefaults.splitKey("t1") == "terminal.split.t1")
        #expect(!TabDefaults.tabListKey(workspace).hasPrefix(TabDefaults.tabPrefix))
    }

    @Test("a tab list that will not decode is doubt, not an answer")
    func unreadableTabList() {
        let (name, defaults) = domain()
        defer { clean(name) }
        defaults.set(Data("not json".utf8), forKey: "center.tabs.w1")

        #expect(TerminalPaneCensus.terminalTabs(of: workspace, in: defaults) == nil)
        #expect(TerminalPaneCensus.census(of: [workspace], in: defaults)
            == .init(doubtful: [workspace]))
    }

    @Test("a split tree that will not decode is doubt, not one pane")
    func unreadableSplitTree() {
        let (name, defaults) = domain()
        defer { clean(name) }
        tabList(defaults)
        defaults.set("not a layout", forKey: "terminal.split.t1")

        #expect(TerminalPaneCensus.panes(ofTab: "t1", in: defaults) == nil)

        #expect(TerminalPaneCensus.census(of: [workspace], in: defaults)
            == .init(panes: ["t3"], doubtful: [workspace]))
    }

    @Test("an unknown tab kind names no pane and raises no doubt")
    func unknownKind() {
        let (name, defaults) = domain()
        defer { clean(name) }
        let json = #"[{"id":"t9","workspaceID":"w1","kind":"canvas","title":"Canvas"}]"#
        defaults.set(Data(json.utf8), forKey: "center.tabs.w1")

        #expect(TerminalPaneCensus.census(of: [workspace], in: defaults) == .init())
    }

    @Test("the panes the sweep can reach are unchanged by the migration")
    func invariantUnderMigration() throws {
        let (name, defaults) = domain()
        defer { clean(name) }
        tabList(defaults)

        var terminal = SplitLayout(pane: "t1")
        terminal.split("t1", axis: .horizontal, into: "x1")
        let shells = try #require(terminal.encoded)
        defaults.set(shells, forKey: "terminal.split.t1")

        var carve = SplitLayout(pane: "c1")
        carve.split("c1", axis: .horizontal, into: "c2")
        carve.split("c2", axis: .vertical, into: "c3")
        carve.split("c3", axis: .horizontal, into: "c4")
        let old = StoredPaneArrangement(
            layout: try #require(carve.encoded),
            contents: ["c1": .chat(SessionID("s1")), "c2": .tool("t1"), "c4": .tool("t1")]
        )
        let panes = try #require(old.encoded)
        defaults.set(panes, forKey: "center.panes.w1")

        let before = TerminalPaneCensus.census(of: [workspace], in: defaults)
        #expect(before == .init(panes: ["t1", "x1", "t3"]))

        let migrated = TabMigration.migrateAll(
            in: defaults, keys: DefaultsSnapshot.own(defaults, name: name).keys
        )

        #expect(migrated.count == 1)
        #expect(TerminalPaneCensus.census(of: [workspace], in: defaults) == before)
    }

    @Test("the migration touches no key the sweep reads")
    func touchesNoTerminalKey() throws {
        let (name, defaults) = domain()
        defer { clean(name) }
        tabList(defaults)
        var terminal = SplitLayout(pane: "t1")
        terminal.split("t1", axis: .horizontal, into: "x1")
        let shells = try #require(terminal.encoded)
        defaults.set(shells, forKey: "terminal.split.t1")

        var carve = SplitLayout(pane: "c1")
        carve.split("c1", axis: .horizontal, into: "c2")
        let old = StoredPaneArrangement(
            layout: try #require(carve.encoded),
            contents: ["c1": .chat(SessionID("s1")), "c2": .tool("t1")]
        )
        let panes = try #require(old.encoded)
        defaults.set(panes, forKey: "center.panes.w1")

        let before = try #require(UserDefaults.standard.persistentDomain(forName: name))
        TabMigration.migrateAll(in: defaults, keys: before.keys)
        let after = try #require(UserDefaults.standard.persistentDomain(forName: name))

        #expect(Set(before.keys) == ["center.tabs.w1", "terminal.split.t1", "center.panes.w1"])
        #expect(Set(after.keys) == ["center.tabs.w1", "terminal.split.t1", "center.tab.s1"])
        #expect(after["center.tabs.w1"] as? Data == before["center.tabs.w1"] as? Data)
        #expect(after["terminal.split.t1"] as? String == before["terminal.split.t1"] as? String)
    }

    @Test("every tool the carve pointed at is still pointed at afterwards")
    func toolsSurvive() throws {
        var carve = SplitLayout(pane: "c1")
        carve.split("c1", axis: .horizontal, into: "c2")
        carve.split("c2", axis: .vertical, into: "c3")
        let old = StoredPaneArrangement(
            layout: try #require(carve.encoded),
            contents: ["c1": .tool("t1"), "c2": .chat(SessionID("s1")), "c3": .tool("t1")]
        )

        let tab = try #require(TabMigration.invert(old))

        #expect(Set(old.contents.values.map(\.id)) == Set(tab.stored.contents.values.map(\.id)))
    }
}
