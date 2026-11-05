import Testing
@testable import Core

@Suite("CanvasSnapping")
struct CanvasSnappingTests {
    private let other = CanvasRect(x: 100, y: 100, width: 50, height: 50)

    @Test func snapsWithinTolerance() {
        let moving = CanvasRect(x: 97, y: 0, width: 20, height: 20)
        let result = CanvasSnapping.snap(moving, against: [other], frame: nil)
        #expect(result.rect.origin.x == 100)
        #expect(result.rect.origin.y == 0)
        #expect(result.guides.contains { $0.axis == .vertical && $0.position == 100 })
    }

    @Test func ignoresBeyondTolerance() {
        let moving = CanvasRect(x: 100 + CanvasSnapping.tolerance + 1, y: 0, width: 10, height: 20)
        let result = CanvasSnapping.snap(moving, against: [other], frame: nil)
        #expect(result.rect == moving)
        #expect(result.guides.isEmpty)
    }

    @Test func snapsToFrameCentre() {
        let frame = CanvasRect(x: 0, y: 0, width: 400, height: 300)
        let moving = CanvasRect(x: 192, y: 143, width: 20, height: 20)
        let result = CanvasSnapping.snap(moving, against: [], frame: frame)
        #expect(result.rect.origin.x == 190)
        #expect(result.rect.origin.y == 140)
        #expect(result.guides.contains { $0.axis == .vertical && $0.position == 200 })
        #expect(result.guides.contains { $0.axis == .horizontal && $0.position == 150 })
    }

    @Test func snapsToTheNearestOfSeveralTargets() {
        let moving = CanvasRect(x: 0, y: 0, width: 20, height: 20)
        let near = CanvasRect(x: 4, y: 500, width: 0, height: 10)
        let nearer = CanvasRect(x: 2, y: 900, width: 0, height: 10)
        let result = CanvasSnapping.snap(moving, against: [near, nearer], frame: nil)
        #expect(result.rect.origin.x == 2)
    }

    @Test func moveSnapsTheGroupAndKeepsFrames() {
        let frame = CanvasFrame(id: CanvasFrameID("f"), name: "F", rect: CanvasRect(x: 1_000, y: 0, width: 400, height: 400))
        let anchor = CanvasElement(
            id: CanvasElementID("anchor"), frameID: frame.id,
            rect: CanvasRect(x: 100, y: 100, width: 50, height: 50), kind: .shape(CanvasShape(kind: .rectangle))
        )
        let mover = CanvasElement(
            id: CanvasElementID("mover"), frameID: frame.id,
            rect: CanvasRect(x: 10, y: 10, width: 20, height: 20), kind: .shape(CanvasShape(kind: .rectangle))
        )
        let document = CanvasDocument(frames: [frame], elements: [anchor, mover])
        let plan = CanvasMove.plan(moving: [mover.id], by: CanvasPoint(x: 87, y: 0), in: document)
        let operations = CanvasMove.operations(moving: [mover.id], by: plan.delta, in: document)
        var session = CanvasDocumentSession(document: document)
        let outcome = session.apply(operations, by: .owner)
        #expect(plan.delta.x == 90)
        #expect(operations.count == 1)
        #expect(session.document.elements.last?.rect.origin.x == 100)
        #expect(session.document.elements.last?.frameID == frame.id)
        if case .applied = outcome {} else { Issue.record("not applied") }
    }
}
