import Foundation
import Testing
@testable import Core

@Suite("TabDragOrder")
struct TabDragOrderTests {
    private let run = ["a", "b", "c"]
    private let centres: [String: Double] = ["a": 50, "b": 130, "c": 230]

    @Test("a tab that has not passed anything stays where it is")
    func stillHome() {
        #expect(TabDragOrder.live(run, moving: "a", centres: centres, to: 50) == run)
        #expect(TabDragOrder.live(run, moving: "b", centres: centres, to: 130) == run)
    }

    @Test("a tab dragged past its neighbour's middle changes places with it")
    func pastOne() {
        #expect(TabDragOrder.live(run, moving: "a", centres: centres, to: 131) == ["b", "a", "c"])
        #expect(TabDragOrder.live(run, moving: "c", centres: centres, to: 129) == ["a", "c", "b"])
    }

    @Test("a tab dragged to the far end lands at the far end")
    func allTheWay() {
        #expect(TabDragOrder.live(run, moving: "a", centres: centres, to: 400) == ["b", "c", "a"])
        #expect(TabDragOrder.live(run, moving: "c", centres: centres, to: -50) == ["c", "a", "b"])
    }

    @Test("a pointer resting exactly on a centre has not passed it")
    func exactlyOnTheBoundary() {
        #expect(TabDragOrder.live(run, moving: "a", centres: centres, to: 130) == run)
        #expect(TabDragOrder.live(run, moving: "a", centres: centres, to: 130.001) == ["b", "a", "c"])
    }

    @Test("a drag rearranges the list and cannot leave it")
    func staysInItsRun() {
        let order = TabDragOrder.live(run, moving: "a", centres: centres, to: 5000)

        #expect(Set(order) == Set(run))
        #expect(order.count == run.count)
        #expect(order == ["b", "c", "a"])
    }

    @Test("a run with one tab in it has no order to change")
    func loneTab() {
        #expect(TabDragOrder.live(["a"], moving: "a", centres: ["a": 50], to: 900) == ["a"])
    }

    @Test("a tab that is not in the run moves nothing")
    func stranger() {
        #expect(TabDragOrder.live(run, moving: "z", centres: centres, to: 200) == run)
    }

    @Test("nothing moves until every tab in the run has been measured")
    func unmeasured() {
        #expect(TabDragOrder.live(run, moving: "a", centres: ["a": 50, "b": 130], to: 400) == run)
        #expect(TabDragOrder.live(run, moving: "a", centres: [:], to: 400) == run)
    }

    @Test("every position of the pointer leaves the run whole")
    func alwaysAPermutation() {
        for pointer in stride(from: -200.0, through: 600.0, by: 7) {
            for moved in run {
                let order = TabDragOrder.live(run, moving: moved, centres: centres, to: pointer)
                #expect(order.count == run.count)
                #expect(Set(order) == Set(run))
            }
        }
    }
}
