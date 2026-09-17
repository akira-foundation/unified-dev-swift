import Testing
@testable import Core

@Suite("Pane naming")
struct PaneNamingTests {
    @Test("The first pane of a kind wears the bare name")
    func firstIsBare() {
        #expect(PaneNaming.nextTitle(base: PaneNaming.chat, taken: []) == "Chat")
        #expect(PaneNaming.nextTitle(base: PaneNaming.browser, taken: ["Chat"]) == "Browser")
    }

    @Test("A second pane of a kind is numbered from two")
    func secondIsTwo() {
        #expect(PaneNaming.nextTitle(base: "Chat", taken: ["Chat"]) == "Chat 2")
    }

    @Test("Numbering climbs past every number already out")
    func climbs() {
        #expect(PaneNaming.nextTitle(base: "Chat", taken: ["Chat", "Chat 2"]) == "Chat 3")
        #expect(
            PaneNaming.nextTitle(base: "Chat", taken: ["Chat", "Chat 2", "Chat 3"]) == "Chat 4"
        )
    }

    @Test("A closed pane's number is handed out again")
    func reusesTheGap() {
        #expect(PaneNaming.nextTitle(base: "Chat", taken: ["Chat", "Chat 3"]) == "Chat 2")
    }

    @Test("The bare name is reused when only numbered panes are left")
    func reusesTheBareName() {
        #expect(PaneNaming.nextTitle(base: "Chat", taken: ["Chat 2", "Chat 3"]) == "Chat")
    }

    @Test("A name somebody typed is taken like any other")
    func respectsTypedNames() {
        #expect(PaneNaming.nextTitle(base: "Chat", taken: ["Chat", "Chat 2"]) == "Chat 3")
    }

    @Test("A chat named from its content holds no number")
    func ignoresContentNames() {
        #expect(PaneNaming.nextTitle(base: "Chat", taken: ["Are you there"]) == "Chat")
    }

    @Test("Numbering is per kind")
    func perKind() {
        let taken = ["Chat", "Chat 2", "Terminal"]
        #expect(PaneNaming.nextTitle(base: "Chat", taken: taken) == "Chat 3")
        #expect(PaneNaming.nextTitle(base: "Terminal", taken: taken) == "Terminal 2")
    }

    @Test("Default names are recognised")
    func recognisesDefaults() {
        #expect(PaneNaming.isDefaultTitle("Terminal", base: "Terminal"))
        #expect(PaneNaming.isDefaultTitle("Terminal 2", base: "Terminal"))
        #expect(PaneNaming.isDefaultTitle("Terminal 40", base: "Terminal"))
    }

    @Test("A name somebody typed is not a default")
    func rejectsTypedNames() {
        #expect(!PaneNaming.isDefaultTitle("Terminal server", base: "Terminal"))
        #expect(!PaneNaming.isDefaultTitle("Terminal2", base: "Terminal"))
        #expect(!PaneNaming.isDefaultTitle("", base: "Terminal"))
        #expect(!PaneNaming.isDefaultTitle("Chat", base: "Terminal"))
    }
}
