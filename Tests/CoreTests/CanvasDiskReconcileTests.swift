import Foundation
import Testing
@testable import Core

@Suite("CanvasDiskReconcile")
struct CanvasDiskReconcileTests {
    private let held = CanvasSessionFixture().session().document

    private func encoded(_ document: CanvasDocument) throws -> Data {
        try CanvasDocumentCodec.encode(document)
    }

    private func reformatted(_ document: CanvasDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(document)
    }

    @Test func ownWriteIsUnchanged() throws {
        let bytes = try encoded(held)
        var edited = held
        edited.elements.removeLast()

        let outcome = CanvasDiskReconcile.decide(disk: bytes, lastWritten: bytes, held: edited)

        guard case .unchanged = outcome else {
            Issue.record("our own bytes were taken as an outside change: \(outcome)")
            return
        }
    }

    @Test func aSaveInFlightIsUnchanged() throws {
        let last = try encoded(held)
        var edited = held
        edited.elements.removeLast()
        let writing = try encoded(edited)

        let outcome = CanvasDiskReconcile.decide(disk: writing, lastWritten: last, held: edited, writing: writing)

        guard case .unchanged = outcome else {
            Issue.record("bytes being written were taken as an outside change: \(outcome)")
            return
        }
    }

    @Test func outsideChangeReloadsAndKeepsABackup() throws {
        let last = try encoded(held)
        var outside = held
        outside.elements.removeLast()
        let disk = try encoded(outside)

        let outcome = CanvasDiskReconcile.decide(disk: disk, lastWritten: last, held: held)

        guard case .reload(let document, keepBackup: true) = outcome else {
            Issue.record("expected a reload with a copy, got \(outcome)")
            return
        }
        #expect(document == outside)
    }

    @Test func differentFormattingOfTheSameDocumentReloadsWithoutACopy() throws {
        let last = try encoded(held)
        let disk = try reformatted(held)
        #expect(disk != last)

        let outcome = CanvasDiskReconcile.decide(disk: disk, lastWritten: last, held: held)

        guard case .reload(let document, keepBackup: false) = outcome else {
            Issue.record("expected a reload with no copy, got \(outcome)")
            return
        }
        #expect(document == held)
    }

    @Test func aCommentDateFinerThanTheFileStillCountsAsTheSameDocument() throws {
        var document = held
        document.comments = [CanvasComment(
            anchor: CanvasPoint(x: 1, y: 1), text: "Here", createdAt: Date(timeIntervalSince1970: 1_000.25)
        )]
        let disk = try reformatted(document)

        let outcome = CanvasDiskReconcile.decide(disk: disk, lastWritten: nil, held: document)

        guard case .reload(_, keepBackup: false) = outcome else {
            Issue.record("expected a reload with no copy, got \(outcome)")
            return
        }
    }

    @Test func differentFormattingOfADifferentDocumentKeepsACopy() throws {
        var outside = held
        outside.frames[0].name = "Renamed"

        let outcome = CanvasDiskReconcile.decide(
            disk: try reformatted(outside), lastWritten: try encoded(held), held: held
        )

        guard case .reload(_, keepBackup: true) = outcome else {
            Issue.record("expected a reload with a copy, got \(outcome)")
            return
        }
    }

    @Test func corruptOutsideChangeIsRefused() throws {
        let outcome = CanvasDiskReconcile.decide(
            disk: Data("{ not json".utf8), lastWritten: try encoded(held), held: held
        )

        guard case .refused(let reason) = outcome else {
            Issue.record("a corrupt file was not refused: \(outcome)")
            return
        }
        #expect(reason.contains("cannot be read"))
    }

    @Test func aNewerVersionOnDiskIsRefused() throws {
        let outcome = CanvasDiskReconcile.decide(
            disk: Data(#"{"version":99}"#.utf8), lastWritten: try encoded(held), held: held
        )

        guard case .refused(let reason) = outcome else {
            Issue.record("a newer file was not refused: \(outcome)")
            return
        }
        #expect(reason.contains("99"))
    }

    @Test func missingFileIsVanished() throws {
        let outcome = CanvasDiskReconcile.decide(disk: nil, lastWritten: try encoded(held), held: held)

        guard case .vanished = outcome else {
            Issue.record("a missing file was not vanished: \(outcome)")
            return
        }
    }
}
