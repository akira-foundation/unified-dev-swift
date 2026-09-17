import Foundation
import Testing
@testable import Core

@Suite("TabReorder")
struct TabReorderTests {
    @Test("a run drawn without its absorbed tab still writes a change")
    func hiddenEntryDoesNotSwallowTheMove() {
        let order = TabReorder.apply(["t3", "t1"], to: ["t1", "t2", "t3"])

        #expect(order == ["t3", "t2", "t1"])
        #expect(order?.filter { $0 != "t2" } == ["t3", "t1"])
    }

    @Test("what the strip cannot see does not move")
    func hiddenEntriesKeepTheirSlots() {
        let order = TabReorder.apply(["c", "a"], to: ["a", "hidden", "b", "c"])

        #expect(order == ["c", "hidden", "b", "a"])
        #expect(order?[1] == "hidden")
    }

    @Test("a plain swap of two neighbours")
    func swap() {
        #expect(TabReorder.apply(["b", "a", "c"], to: ["a", "b", "c"]) == ["b", "a", "c"])
    }

    @Test("a tab carried the length of the run")
    func acrossTheRun() {
        #expect(TabReorder.apply(["b", "c", "a"], to: ["a", "b", "c"]) == ["b", "c", "a"])
        #expect(TabReorder.apply(["c", "a", "b"], to: ["a", "b", "c"]) == ["c", "a", "b"])
    }

    @Test("a tab let go where it started writes nothing")
    func noChange() {
        #expect(TabReorder.apply(["a", "b", "c"], to: ["a", "b", "c"]) == nil)
        #expect(TabReorder.apply(["a", "c"], to: ["a", "b", "c"]) == nil)
    }

    @Test("a drawn order that does not account for what it claims to be writes nothing")
    func staleReading() {
        #expect(TabReorder.apply(["a", "z"], to: ["a", "b", "c"]) == nil)
        #expect(TabReorder.apply(["a", "a"], to: ["a", "b", "c"]) == nil)
        #expect(TabReorder.apply([String](), to: ["a", "b"]) == nil)
    }

    @Test("an empty run has nothing to write")
    func empty() {
        #expect(TabReorder.apply([String](), to: [String]()) == nil)
    }

    @Test("the conversations run is decided by the same rule as the tools run")
    func typedIdentifiers() {
        let one = SessionID("s1")
        let two = SessionID("s2")
        let three = SessionID("s3")

        #expect(TabReorder.apply([three, one], to: [one, two, three]) == [three, two, one])
    }

    @Test("a written order holds exactly what the stored one held")
    func alwaysAPermutation() {
        let all = ["a", "hidden", "b", "c"]
        for visible in [["a", "b", "c"], ["c", "b", "a"], ["b", "c", "a"], ["c", "a"], ["b", "a"]] {
            guard let order = TabReorder.apply(visible, to: all) else { continue }
            #expect(order.count == all.count)
            #expect(Set(order) == Set(all))
        }
    }
}
