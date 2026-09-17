import CoreGraphics
import Foundation
import Testing
@testable import Core

@Suite("PaneLanding")
struct PaneLandingTests {
    private let size = CGSize(width: 400, height: 200)

    private func sideBySide() -> SplitGeometry {
        var layout = SplitLayout(pane: "a")
        layout.split("a", axis: .horizontal, into: "b")
        return layout.geometry(in: size, dividerThickness: 0)
    }

    @Test("the middle of a pane is the middle")
    func middle() {
        #expect(PaneRegion.at(CGPoint(x: 200, y: 100), in: size) == .whole)
    }

    @Test("each edge is a quarter of the pane along that side")
    func edges() {
        #expect(PaneRegion.at(CGPoint(x: 99, y: 100), in: size) == .leading)
        #expect(PaneRegion.at(CGPoint(x: 101, y: 100), in: size) == .whole)
        #expect(PaneRegion.at(CGPoint(x: 301, y: 100), in: size) == .trailing)
        #expect(PaneRegion.at(CGPoint(x: 200, y: 49), in: size) == .top)
        #expect(PaneRegion.at(CGPoint(x: 200, y: 151), in: size) == .bottom)
    }

    @Test("a corner belongs to the side rather than to the top or bottom")
    func corners() {
        #expect(PaneRegion.at(CGPoint(x: 10, y: 10), in: size) == .leading)
        #expect(PaneRegion.at(CGPoint(x: 390, y: 190), in: size) == .trailing)
    }

    @Test("a pane with no size at all is all middle")
    func degenerate() {
        #expect(PaneRegion.at(.zero, in: .zero) == .whole)
        #expect(PaneRegion.at(CGPoint(x: 5, y: 5), in: CGSize(width: 0, height: 10)) == .whole)
    }

    @Test("the middle is not a placement, and each edge is one")
    func placements() {
        #expect(PaneRegion.whole.placement == nil)

        #expect(PaneRegion.leading.placement?.axis == .horizontal)
        #expect(PaneRegion.leading.placement?.before == true)
        #expect(PaneRegion.trailing.placement?.axis == .horizontal)
        #expect(PaneRegion.trailing.placement?.before == false)
        #expect(PaneRegion.top.placement?.axis == .vertical)
        #expect(PaneRegion.top.placement?.before == true)
        #expect(PaneRegion.bottom.placement?.axis == .vertical)
        #expect(PaneRegion.bottom.placement?.before == false)
    }

    @Test("the middle washes the whole pane and an edge washes a quarter of it")
    func washes() {
        let pane = CGRect(x: 100, y: 50, width: 400, height: 200)

        #expect(PaneRegion.whole.frame(in: pane) == pane)
        #expect(PaneRegion.leading.frame(in: pane) == CGRect(x: 100, y: 50, width: 100, height: 200))
        #expect(PaneRegion.trailing.frame(in: pane) == CGRect(x: 400, y: 50, width: 100, height: 200))
        #expect(PaneRegion.top.frame(in: pane) == CGRect(x: 100, y: 50, width: 400, height: 50))
        #expect(PaneRegion.bottom.frame(in: pane) == CGRect(x: 100, y: 200, width: 400, height: 50))
    }

    @Test("no wash escapes the pane it belongs to")
    func washesStayInside() {
        let pane = CGRect(x: 12, y: 34, width: 321, height: 123)
        for region in PaneRegion.allCases {
            #expect(pane.contains(region.frame(in: pane)))
        }
    }

    @Test("a point picks out the pane it is in and the part of it")
    func landingInAPane() {
        let geometry = sideBySide()

        let left = geometry.landing(at: CGPoint(x: 100, y: 100))
        #expect(left?.pane == "a")
        #expect(left?.region == .whole)

        let rightEdgeOfLeft = geometry.landing(at: CGPoint(x: 195, y: 100))
        #expect(rightEdgeOfLeft?.pane == "a")
        #expect(rightEdgeOfLeft?.region == .trailing)

        let right = geometry.landing(at: CGPoint(x: 300, y: 100))
        #expect(right?.pane == "b")
        #expect(right?.region == .whole)
    }

    @Test("the wash comes back in the column's coordinates")
    func landingFrameIsAbsolute() {
        let landing = sideBySide().landing(at: CGPoint(x: 195, y: 100))

        #expect(landing?.frame == CGRect(x: 150, y: 0, width: 50, height: 200))
    }

    @Test("a point outside every pane lands nowhere")
    func landingOutside() {
        let geometry = sideBySide()

        #expect(geometry.landing(at: CGPoint(x: -1, y: 100)) == nil)
        #expect(geometry.landing(at: CGPoint(x: 401, y: 100)) == nil)
        #expect(geometry.landing(at: CGPoint(x: 200, y: 201)) == nil)
    }

    @Test("a point on a divider lands nowhere rather than being snapped to a neighbour")
    func landingOnADivider() {
        var layout = SplitLayout(pane: "a")
        layout.split("a", axis: .horizontal, into: "b")
        let geometry = layout.geometry(in: size, dividerThickness: 10)

        #expect(geometry.dividers.first?.frame.minX == 195)
        #expect(geometry.landing(at: CGPoint(x: 200, y: 100)) == nil)
    }

    @Test("a tab that has never been split is one pane covering the whole column")
    func landingInASinglePane() {
        let geometry = SplitLayout(pane: "only").geometry(in: size, dividerThickness: 0)

        #expect(geometry.landing(at: CGPoint(x: 200, y: 100))?.pane == "only")
        #expect(geometry.landing(at: CGPoint(x: 10, y: 100))?.region == .leading)
    }

    @Test("a zoomed pane is the whole column")
    func landingWhileZoomed() {
        var layout = SplitLayout(pane: "a")
        layout.split("a", axis: .horizontal, into: "b")
        _ = layout.toggleZoom()
        let geometry = layout.geometry(in: size, dividerThickness: 0)

        #expect(geometry.landing(at: CGPoint(x: 10, y: 100))?.pane == "b")
        #expect(geometry.landing(at: CGPoint(x: 390, y: 100))?.pane == "b")
    }

    @Test("a nested tree can be landed in anywhere it draws a pane")
    func landingInANestedTree() {
        var layout = SplitLayout(pane: "a")
        layout.split("a", axis: .horizontal, into: "b")
        layout.split("b", axis: .vertical, into: "c")
        let geometry = layout.geometry(in: size, dividerThickness: 0)

        var found: Set<String> = []
        for frame in geometry.panes {
            let landing = geometry.landing(at: CGPoint(x: frame.frame.midX, y: frame.frame.midY))
            #expect(landing?.pane == frame.pane)
            #expect(landing?.region == .whole)
            if let pane = landing?.pane { found.insert(pane) }
        }
        #expect(found == Set(layout.panes))
    }
}
