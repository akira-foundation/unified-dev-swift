import Foundation
import Testing
@testable import Core

@Suite("TabMigration")
struct TabMigrationTests {
    private let chat = SessionID("s1")
    private let other = SessionID("s2")

    private func nested() -> SplitLayout {
        var layout = SplitLayout(pane: "p1")
        layout.split("p1", axis: .horizontal, into: "p2")
        layout.split("p2", axis: .vertical, into: "p3")
        layout.setRatio(0.7, at: [])
        layout.setFocus("p1")
        return layout
    }

    private func arrangement(
        _ layout: SplitLayout, _ contents: [String: PaneContent]
    ) throws -> StoredPaneArrangement {
        StoredPaneArrangement(layout: try #require(layout.encoded), contents: contents)
    }

    private func tree(of tab: TabMigration.CompositeTab) throws -> SplitLayout {
        try #require(SplitLayout(encoded: tab.stored.layout))
    }

    @Test("the stored shape decodes what the workspace carve has been written as")
    func wireFormat() throws {
        let json = #"""
        {"layout":"{\"root\":{\"pane\":{\"_0\":\"p1\"}},\"focus\":\"p1\"}",\#
        "contents":{"p1":{"chat":{"_0":"s1"}},"p2":{"tool":{"_0":"t1"}}}}
        """#
        let data = try #require(json.data(using: .utf8))
        let stored = try #require(StoredPaneArrangement(decoding: data))

        #expect(stored.contents["p1"] == .chat(chat))
        #expect(stored.contents["p2"] == .tool("t1"))
        #expect(SplitLayout(encoded: stored.layout)?.panes == ["p1"])
    }

    @Test("encoding a record sorts its keys")
    func sortedKeys() throws {
        let stored = StoredPaneArrangement(
            layout: "L", contents: ["b": .tool("t1"), "a": .chat(chat)]
        )

        let text = String(data: try #require(stored.encoded), encoding: .utf8)

        #expect(text == #"{"contents":{"a":{"chat":{"_0":"s1"}},"b":{"tool":{"_0":"t1"}}},"layout":"L"}"#)
    }

    @Test("a content answers to the id of whatever it points at")
    func contentIdentity() {
        #expect(PaneContent.chat(chat).id == "s1")
        #expect(PaneContent.tool("t1").id == "t1")
        #expect(TabDefaults.tabKey(root: .chat(chat)) == "center.tab.s1")
    }

    @Test("a plain split of two conversations becomes one tab rooted at the first")
    func plainSplit() throws {
        var layout = SplitLayout(pane: "p1")
        layout.split("p1", axis: .horizontal, into: "p2")
        let old = try arrangement(layout, ["p1": .chat(chat), "p2": .chat(other)])

        let tab = try #require(TabMigration.invert(old))

        let after = try tree(of: tab)

        #expect(tab.root == .chat(chat))
        #expect(tab.key == "center.tab.s1")
        #expect(after.panes == ["p1", "p2"])
        #expect(tab.stored.contents == old.contents)
    }

    @Test("a carve with no conversation in it is rooted at its first pane")
    func toolsOnly() throws {
        var layout = SplitLayout(pane: "p1")
        layout.split("p1", axis: .horizontal, into: "p2")
        let old = try arrangement(layout, ["p1": .tool("t1"), "p2": .tool("t2")])

        let tab = try #require(TabMigration.invert(old))

        #expect(tab.root == .tool("t1"))
    }

    @Test("a conversation roots the tab even when a tool comes before it")
    func chatWins() throws {
        var layout = SplitLayout(pane: "p1")
        layout.split("p1", axis: .horizontal, into: "p2")
        let old = try arrangement(layout, ["p1": .tool("t1"), "p2": .chat(chat)])

        #expect(TabMigration.invert(old)?.root == .chat(chat))
    }

    @Test("a nested tree keeps its shape, its ratios and its pane ids")
    func nestedTree() throws {
        let old = try arrangement(
            nested(), ["p1": .chat(chat), "p2": .chat(other), "p3": .tool("t1")]
        )

        let tab = try #require(TabMigration.invert(old))
        let after = try tree(of: tab)

        #expect(after.root == .split(
            axis: .horizontal,
            ratio: 0.7,
            first: .pane("p1"),
            second: .split(axis: .vertical, ratio: 0.5, first: .pane("p2"), second: .pane("p3"))
        ))
        #expect(after.panes == ["p1", "p2", "p3"])
        #expect(tab.stored.contents.count == 3)
    }

    @Test("a pane pointing at nothing is dropped and its split collapses")
    func nilPaneDropped() throws {
        let old = try arrangement(nested(), ["p1": .chat(chat), "p3": .tool("t1")])

        let tab = try #require(TabMigration.invert(old))
        let after = try tree(of: tab)

        #expect(after.root == .split(
            axis: .horizontal, ratio: 0.7, first: .pane("p1"), second: .pane("p3")
        ))
        #expect(after.panes == ["p1", "p3"])
        #expect(tab.stored.contents == ["p1": .chat(chat), "p3": .tool("t1")])
    }

    @Test("a carve of nothing but panes pointing at nothing migrates to nothing")
    func allNil() throws {
        let old = try arrangement(nested(), [:])

        #expect(TabMigration.invert(old) == nil)
    }

    @Test("a carve that collapses to one pane migrates to nothing")
    func collapsesToOne() throws {
        var layout = SplitLayout(pane: "p1")
        layout.split("p1", axis: .horizontal, into: "p2")
        let old = try arrangement(layout, ["p2": .chat(chat)])

        #expect(TabMigration.invert(old) == nil)
    }

    @Test("one conversation may hold two panes")
    func duplicateChat() throws {
        var layout = SplitLayout(pane: "p1")
        layout.split("p1", axis: .horizontal, into: "p2")
        let old = try arrangement(layout, ["p1": .chat(chat), "p2": .chat(chat)])

        let tab = try #require(TabMigration.invert(old))
        let after = try tree(of: tab)

        #expect(tab.root == .chat(chat))
        #expect(after.panes == ["p1", "p2"])
        #expect(tab.stored.contents == ["p1": .chat(chat), "p2": .chat(chat)])
    }

    @Test("one tool keeps its first pane and loses the later one")
    func duplicateTool() throws {
        let old = try arrangement(
            nested(), ["p1": .tool("t1"), "p2": .chat(chat), "p3": .tool("t1")]
        )

        let tab = try #require(TabMigration.invert(old))
        let after = try tree(of: tab)

        #expect(after.panes == ["p1", "p2"])
        #expect(tab.stored.contents == ["p1": .tool("t1"), "p2": .chat(chat)])
        #expect(tab.root == .chat(chat))
    }

    @Test("focus stays where it was when its pane survives")
    func focusSurvives() throws {
        let old = try arrangement(nested(), ["p1": .chat(chat), "p3": .tool("t1")])

        let tab = try #require(TabMigration.invert(old))

        #expect(try tree(of: tab).focus == "p1")
    }

    @Test("focus moves to the survivor when its own pane is dropped")
    func focusMoves() throws {
        var layout = nested()
        layout.setFocus("p2")
        let old = try arrangement(layout, ["p1": .chat(chat), "p3": .tool("t1")])

        let tab = try #require(TabMigration.invert(old))

        #expect(try tree(of: tab).focus == "p3")
    }

    @Test("a moved divider keeps where it was moved to")
    func ratioSurvives() throws {
        var layout = nested()
        layout.setRatio(0.25, at: [1])
        let old = try arrangement(
            layout, ["p1": .chat(chat), "p2": .chat(other), "p3": .tool("t1")]
        )

        let tab = try #require(TabMigration.invert(old))
        let after = try tree(of: tab)

        #expect(after.ratio(at: []) == 0.7)
        #expect(after.ratio(at: [1]) == 0.25)
    }

    @Test("no pane is given a new id")
    func paneIdentitiesUnchanged() throws {
        let old = try arrangement(
            nested(), ["p1": .chat(chat), "p2": .chat(other), "p3": .tool("t1")]
        )

        let tab = try #require(TabMigration.invert(old))
        let after = try tree(of: tab)

        #expect(Set(after.panes).isSubset(of: ["p1", "p2", "p3"]))
        #expect(Set(tab.stored.contents.keys).isSubset(of: ["p1", "p2", "p3"]))
    }

    @Test("a layout that will not decode migrates to nothing")
    func undecodableLayout() {
        let old = StoredPaneArrangement(layout: "not json", contents: ["p1": .chat(chat)])

        #expect(TabMigration.invert(old) == nil)
    }

    @Test("inverting twice produces identical bytes")
    func replayConverges() throws {
        var layout = nested()
        layout.split("p3", axis: .horizontal, into: "p4")
        let old = try arrangement(
            layout, ["p1": .chat(chat), "p3": .tool("t1"), "p4": .tool("t1")]
        )

        let once = try #require(TabMigration.invert(old))
        let twice = try #require(TabMigration.invert(old))
        let again = try #require(TabMigration.invert(once.stored))

        #expect(once == twice)
        #expect(once.stored.encoded == twice.stored.encoded)
        #expect(again.root == once.root)
        #expect(again.stored.encoded == once.stored.encoded)
    }
}

@Suite("TabMigration over user defaults")
struct TabMigrationDefaultsTests {
    private let workspace = WorkspaceID("w1")
    private let chat = SessionID("s1")

    private func domain() -> (name: String, defaults: UserDefaults) {
        let name = "unifieddev.test.tabs.\(UUID().uuidString)"
        return (name, UserDefaults(suiteName: name)!)
    }

    private func clean(_ name: String) {
        UserDefaults.standard.removePersistentDomain(forName: name)
    }

    private func carve() throws -> StoredPaneArrangement {
        var layout = SplitLayout(pane: "c1")
        layout.split("c1", axis: .horizontal, into: "c2")
        return StoredPaneArrangement(
            layout: try #require(layout.encoded),
            contents: ["c1": .chat(chat), "c2": .tool("t1")]
        )
    }

    @Test("a workspace with no carve migrates to nothing and writes nothing")
    func absentKey() {
        let (name, defaults) = domain()
        defer { clean(name) }

        #expect(TabMigration.migrate(workspaceID: workspace, in: defaults) == nil)
        #expect(UserDefaults.standard.persistentDomain(forName: name)?.isEmpty ?? true)
    }

    @Test("the new key is written and only then is the old one dropped")
    func writeThenDelete() throws {
        let (name, defaults) = domain()
        defer { clean(name) }
        let carved = try #require(carve().encoded)
        defaults.set(carved, forKey: "center.panes.w1")

        let tab = try #require(TabMigration.migrate(workspaceID: workspace, in: defaults))

        #expect(tab.key == "center.tab.s1")
        #expect(defaults.data(forKey: "center.tab.s1") == tab.stored.encoded)
        #expect(defaults.data(forKey: "center.panes.w1") == nil)
    }

    @Test("a run interrupted before the delete converges on the same bytes")
    func replayAfterACrash() throws {
        let (name, defaults) = domain()
        defer { clean(name) }
        let old = try #require(carve().encoded)
        defaults.set(old, forKey: "center.panes.w1")

        TabMigration.migrate(workspaceID: workspace, in: defaults)
        let first = defaults.data(forKey: "center.tab.s1")

        defaults.set(old, forKey: "center.panes.w1")
        TabMigration.migrate(workspaceID: workspace, in: defaults)

        #expect(defaults.data(forKey: "center.tab.s1") == first)
        #expect(defaults.data(forKey: "center.panes.w1") == nil)
    }

    @Test("a carve that will not decode is dropped rather than read again")
    func undecodable() {
        let (name, defaults) = domain()
        defer { clean(name) }
        defaults.set(Data("not json".utf8), forKey: "center.panes.w1")

        #expect(TabMigration.migrate(workspaceID: workspace, in: defaults) == nil)
        #expect(defaults.data(forKey: "center.panes.w1") == nil)
    }

    @Test("a carve worth no tab drops its key all the same")
    func nothingWorthKeeping() throws {
        let (name, defaults) = domain()
        defer { clean(name) }
        var layout = SplitLayout(pane: "c1")
        layout.split("c1", axis: .horizontal, into: "c2")
        let old = StoredPaneArrangement(layout: try #require(layout.encoded), contents: [:])
        let carved = try #require(old.encoded)
        defaults.set(carved, forKey: "center.panes.w1")

        #expect(TabMigration.migrate(workspaceID: workspace, in: defaults) == nil)
        #expect(defaults.data(forKey: "center.panes.w1") == nil)
    }

    @Test("every workspace with a carve is migrated, in a stable order")
    func migratesEveryWorkspace() throws {
        let (name, defaults) = domain()
        defer { clean(name) }
        let first = try #require(carve().encoded)
        defaults.set(first, forKey: "center.panes.w1")

        var layout = SplitLayout(pane: "d1")
        layout.split("d1", axis: .vertical, into: "d2")
        let other = StoredPaneArrangement(
            layout: try #require(layout.encoded),
            contents: ["d1": .chat(SessionID("s2")), "d2": .tool("t2")]
        )
        let second = try #require(other.encoded)
        defaults.set(second, forKey: "center.panes.w2")

        let tabs = TabMigration.migrateAll(
            in: defaults, keys: DefaultsSnapshot.own(defaults, name: name).keys
        )

        #expect(tabs.map(\.key) == ["center.tab.s1", "center.tab.s2"])
        #expect(defaults.data(forKey: "center.panes.w1") == nil)
        #expect(defaults.data(forKey: "center.panes.w2") == nil)
        #expect(defaults.data(forKey: "center.tab.s1") != nil)
        #expect(defaults.data(forKey: "center.tab.s2") != nil)
    }

    @Test("the tab prefix does not swallow the tool tab list")
    func prefixesDoNotCollide() {
        #expect(!"center.tabs.w1".hasPrefix(TabDefaults.tabPrefix))
        #expect("center.tab.s1".hasPrefix(TabDefaults.tabPrefix))
    }
}
