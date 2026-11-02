import Testing
@testable import Core

@Suite("When a preview may ask to leave", .tags(.security))
struct DocumentPreviewExitGateTests {
    @Test("the first link asks")
    func firstAsks() {
        var gate = DocumentPreviewExitGate()
        let asks = gate.begin()
        #expect(asks)
    }

    @Test("a second link while the question is open does not ask again")
    func oneAtATime() {
        var gate = DocumentPreviewExitGate()
        _ = gate.begin()
        let again = gate.begin()
        #expect(!again)
    }

    @Test("once declined, the page cannot ask again")
    func declineSilences() {
        var gate = DocumentPreviewExitGate()
        _ = gate.begin()
        gate.answered(opened: false)
        let again = gate.begin()
        #expect(!again)
    }

    @Test("a reload after a decline lets the page ask again")
    func reloadAsksAgain() {
        var gate = DocumentPreviewExitGate()
        _ = gate.begin()
        gate.answered(opened: false)
        gate.reloaded()
        let again = gate.begin()
        #expect(again)
    }

    @Test("after an accepted link the next one still asks")
    func acceptKeepsAsking() {
        var gate = DocumentPreviewExitGate()
        _ = gate.begin()
        gate.answered(opened: true)
        let again = gate.begin()
        #expect(again)
    }
}
