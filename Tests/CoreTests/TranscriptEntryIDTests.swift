import Testing
import Foundation
@testable import Core

@Suite("What a transcript entry's id promises")
struct TranscriptEntryIDTests {
    @Test("bottom spacing is stable decoration, not a stored or self-updating row")
    func bottomSpacingIsDecoration() {
        #expect(TranscriptEntryID.bottomSpacing.seq == nil)
        #expect(!TranscriptEntryID.bottomSpacing.redrawsItself)
        #expect(TranscriptEntryID.bottomSpacing != .streaming)
        #expect(TranscriptEntryID.bottomSpacing.description == "bottomSpacing")
    }

    @Test("a stored row does not redraw itself")
    func aRowDoesNotRedrawItself() {
        #expect(!TranscriptEntryID.row(0).redrawsItself)
        #expect(!TranscriptEntryID.row(2_981).redrawsItself)
    }

    @Test("the four that re-render from their own observation redraw themselves")
    func theOthersRedrawThemselves() {
        #expect(TranscriptEntryID.streaming.redrawsItself)
        #expect(TranscriptEntryID.setup.redrawsItself)
        #expect(TranscriptEntryID.sending.redrawsItself)
        #expect(TranscriptEntryID.pending(DeliveryID("d1")).redrawsItself)
    }

    @Test("a fold's line has no seq and still does not redraw itself")
    func aFoldDoesNotRedrawItself() {
        #expect(!TranscriptEntryID.fold(41).redrawsItself)
        #expect(TranscriptEntryID.fold(41).seq == nil)
    }

    @Test("every entry that names a stored row draws only what its key says")
    func rowsDoNotRedrawThemselves() {
        let ids: [TranscriptEntryID] = [
            .setup, .row(7), .fold(7), .sending, .streaming, .pending(DeliveryID("d2")),
        ]
        for id in ids where id.seq != nil {
            #expect(!id.redrawsItself)
        }
    }

    @Test("a fold and the row it names are different entries")
    func aFoldIsNotItsFirstRow() {
        #expect(TranscriptEntryID.fold(12) != TranscriptEntryID.row(12))
        #expect(TranscriptEntryID.fold(12).description == "fold.12")
    }
}
