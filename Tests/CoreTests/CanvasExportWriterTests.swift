import Foundation
import Testing
@testable import Core

@Suite("Writing an export into the workspace")
struct CanvasExportWriterTests {
    private let root: URL
    private let outside: URL
    private let fixtureDocumentPath: String

    init() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: "canvas-export-\(UUID().uuidString)")
        root = base.appending(path: "worktree")
        outside = base.appending(path: "outside")
        try FileManager.default.createDirectory(at: root.appending(path: "decks"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        fixtureDocumentPath = root.appending(path: "decks/Spring.udcanvas").path
    }

    private func frame(_ name: String, x: Double, width: Double = 1_080, height: Double = 1_350, id: String? = nil) -> CanvasFrame {
        CanvasFrame(id: CanvasFrameID(id ?? name), name: name, rect: CanvasRect(x: x, y: 0, width: width, height: height))
    }

    private func plan(_ frames: [CanvasFrame]) throws -> CanvasExportPlan {
        try CanvasExportPlan.make(document: CanvasDocument(frames: frames), path: fixtureDocumentPath, worktree: root.path)
    }

    private func pictures(_ plan: CanvasExportPlan, bytes: String = "png") -> [CanvasFrameID: Data] {
        Dictionary(uniqueKeysWithValues: plan.slides.map { ($0.frame.id, Data("\(bytes)-\($0.frame.name)".utf8)) })
    }

    private func listing(_ plan: CanvasExportPlan) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: plan.directory)) ?? []).sorted()
    }

    @Test func itWritesOneNumberedPicturePerFrameBesideTheDocument() throws {
        let plan = try plan([frame("Cover", x: 0), frame("Offer", x: 1_200)])
        let report = try CanvasExportWriter.write(plan, pictures: pictures(plan))
        #expect(report.written == ["01-cover.png", "02-offer.png"])
        #expect(listing(plan) == ["01-cover.png", "02-offer.png"])
        #expect(plan.directory.hasSuffix("/decks/spring.export"))
        #expect(!report.hasProblems)
    }

    @Test func aDocumentAtTheRootOfTheWorkspaceExportsBesideItself() throws {
        let document = CanvasDocument(frames: [frame("Cover", x: 0)])
        let plan = try CanvasExportPlan.make(document: document, path: root.appending(path: "Top.udcanvas").path, worktree: root.path)
        #expect(plan.directory.hasSuffix("/worktree/top.export"))
    }

    @Test func aFrameDeletedOrRenamedLeavesNoStaleSlide() throws {
        let first = try plan([frame("Cover", x: 0), frame("Old", x: 1_200), frame("Last", x: 2_400)])
        _ = try CanvasExportWriter.write(first, pictures: pictures(first))
        let second = try plan([frame("Cover", x: 0), frame("New", x: 1_200)])
        let report = try CanvasExportWriter.write(second, pictures: pictures(second))
        #expect(listing(second) == ["01-cover.png", "02-new.png"])
        #expect(report.removed == ["02-old.png", "03-last.png"])
    }

    @Test func itNeverRemovesAnythingThatIsNotANumberedPicture() throws {
        let plan = try plan([frame("Cover", x: 0)])
        let folder = URL(filePath: plan.directory)
        try FileManager.default.createDirectory(at: folder.appending(path: "02-folder.png"), withIntermediateDirectories: true)
        try Data("keep".utf8).write(to: folder.appending(path: "notes.md"))
        try Data("keep".utf8).write(to: folder.appending(path: "cover.png"))
        try Data("keep".utf8).write(to: folder.appending(path: "01-cover.jpg"))
        try Data("keep".utf8).write(to: folder.appending(path: ".hidden"))
        try FileManager.default.createSymbolicLink(at: folder.appending(path: "09-link.png"), withDestinationURL: outside)
        let report = try CanvasExportWriter.write(plan, pictures: pictures(plan))
        #expect(report.removed.isEmpty)
        #expect(listing(plan) == [".hidden", "01-cover.jpg", "01-cover.png", "02-folder.png", "09-link.png", "cover.png", "notes.md"])
    }

    @Test func aSymbolicLinkWithTheNameOfAPictureIsReplacedAndNeverWrittenThrough() throws {
        let target = outside.appending(path: "victim.txt")
        try Data("original".utf8).write(to: target)
        let plan = try plan([frame("Cover", x: 0)])
        let folder = URL(filePath: plan.directory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: folder.appending(path: "01-cover.png"), withDestinationURL: target)
        _ = try CanvasExportWriter.write(plan, pictures: pictures(plan))
        #expect(try Data(contentsOf: target) == Data("original".utf8))
        #expect(try Data(contentsOf: folder.appending(path: "01-cover.png")) == Data("png-Cover".utf8))
    }

    @Test func anExportFolderThatIsASymbolicLinkOutIsRefusedAndNothingIsWritten() throws {
        let link = root.appending(path: "decks/spring.export")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        #expect(throws: CanvasExportRefusal.directoryIsSymbolicLink("spring.export")) { try plan([frame("Cover", x: 0)]) }
        #expect(try FileManager.default.contentsOfDirectory(atPath: outside.path).isEmpty)
    }

    @Test func aLinkToAnotherFolderInsideTheWorkspaceIsRefusedToo() throws {
        let inside = root.appending(path: "elsewhere")
        try FileManager.default.createDirectory(at: inside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: root.appending(path: "decks/spring.export"), withDestinationURL: inside)
        #expect(throws: CanvasExportRefusal.directoryIsSymbolicLink("spring.export")) { try plan([frame("Cover", x: 0)]) }
    }

    @Test func aLinkPlacedAfterPlanningIsCaughtBeforeWriting() throws {
        let plan = try plan([frame("Cover", x: 0)])
        try FileManager.default.createSymbolicLink(at: URL(filePath: plan.directory), withDestinationURL: outside)
        #expect(throws: CanvasExportRefusal.directoryIsSymbolicLink("spring.export")) {
            try CanvasExportWriter.write(plan, pictures: pictures(plan))
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: outside.path).isEmpty)
    }

    @Test func aFolderOfTheDocumentThatLeadsOutOfTheWorkspaceIsRefused() throws {
        let leaving = root.appending(path: "leaving")
        try FileManager.default.createSymbolicLink(at: leaving, withDestinationURL: outside)
        let document = CanvasDocument(frames: [frame("Cover", x: 0)])
        #expect(throws: CanvasExportRefusal.self) {
            try CanvasExportPlan.make(document: document, path: leaving.appending(path: "Spring.udcanvas").path, worktree: root.path)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: outside.path).isEmpty)
    }

    @Test func aDocumentOutsideTheWorkspaceIsRefused() {
        let document = CanvasDocument(frames: [frame("Cover", x: 0)])
        #expect(throws: CanvasExportRefusal.documentOutsideWorktree) {
            try CanvasExportPlan.make(document: document, path: outside.appending(path: "x.udcanvas").path, worktree: root.path)
        }
    }

    @Test func aFileWhereTheFolderShouldBeIsRefused() throws {
        try Data().write(to: root.appending(path: "decks/spring.export"))
        #expect(throws: CanvasExportRefusal.directoryIsNotAFolder("spring.export")) { try plan([frame("Cover", x: 0)]) }
    }

    @Test func aDocumentWithoutFramesHasNothingToExport() {
        #expect(throws: CanvasExportRefusal.noFrames) { try plan([]) }
    }

    @Test func aFrameAboveTheLimitIsLeftOutByNameAndTheRestIsExported() throws {
        let huge = frame("Poster", x: 1_200, width: 8_193, height: 100)
        let edge = frame("Edge", x: 9_500, width: 8_192, height: 8_192)
        let plan = try plan([frame("Cover", x: 0), huge, edge])
        #expect(plan.slides.map(\.file) == ["01-cover.png", "03-edge.png"])
        #expect(plan.refused.map(\.frame) == ["Poster"])
        let report = try CanvasExportWriter.write(plan, pictures: pictures(plan))
        #expect(report.written == ["01-cover.png", "03-edge.png"])
        #expect(report.refused.first?.reason.contains("8193 by 100") == true)
        #expect(report.hasProblems)
    }

    @Test func aFrameThatBecameTooLargeLosesItsOlderPicture() throws {
        let before = try plan([frame("Cover", x: 0), frame("Poster", x: 1_200)])
        _ = try CanvasExportWriter.write(before, pictures: pictures(before))
        let after = try plan([frame("Cover", x: 0), frame("Poster", x: 1_200, width: 9_000)])
        let report = try CanvasExportWriter.write(after, pictures: pictures(after))
        #expect(listing(after) == ["01-cover.png"])
        #expect(report.removed == ["02-poster.png"])
    }

    @Test func aFrameWithNoPictureIsReportedByNameAndTheOthersAreStillWritten() throws {
        let plan = try plan([frame("Cover", x: 0), frame("Broken", x: 1_200), frame("End", x: 2_400)])
        var made = pictures(plan)
        made[CanvasFrameID("Broken")] = nil
        let report = try CanvasExportWriter.write(plan, pictures: made)
        #expect(report.written == ["01-cover.png", "03-end.png"])
        #expect(report.failed.map(\.frame) == ["Broken"])
    }

    @Test func aFailedFrameKeepsItsOlderPictureInsteadOfLeavingAHole() throws {
        let first = try plan([frame("Cover", x: 0), frame("Broken", x: 1_200)])
        _ = try CanvasExportWriter.write(first, pictures: pictures(first))
        var made = pictures(first, bytes: "newer")
        made[CanvasFrameID("Broken")] = nil
        let report = try CanvasExportWriter.write(first, pictures: made)
        let kept = try Data(contentsOf: URL(filePath: first.directory).appending(path: "02-broken.png"))
        #expect(kept == Data("png-Broken".utf8))
        #expect(report.removed.isEmpty)
    }

    @Test func aWriteThatFailsIsReportedForItsFrameAndTheRestGoOn() throws {
        let plan = try plan([frame("Cover", x: 0), frame("Blocked", x: 1_200), frame("End", x: 2_400)])
        let folder = URL(filePath: plan.directory)
        try FileManager.default.createDirectory(at: folder.appending(path: "02-blocked.png"), withIntermediateDirectories: true)
        try Data("inside".utf8).write(to: folder.appending(path: "02-blocked.png/inner"))
        let report = try CanvasExportWriter.write(plan, pictures: pictures(plan))
        #expect(report.written == ["01-cover.png", "03-end.png"])
        #expect(report.failed.map(\.frame) == ["Blocked"])
        #expect(report.tone == .warning)
    }

    @Test func nothingWrittenIsAnError() throws {
        let plan = try plan([frame("Cover", x: 0)])
        let report = try CanvasExportWriter.write(plan, pictures: [:])
        #expect(report.tone == .error)
        #expect(report.title(in: root.path) == "Nothing was exported")
    }

    @Test func aMissingPictureFileIsNamedOnceAndAFoundOneIsNot() throws {
        let cover = frame("Cover", x: 0)
        try Data("x".utf8).write(to: root.appending(path: "decks/here.png"))
        let elements = ["here.png", "gone.png", "gone.png", "../../outside/x.png", "/etc/hosts"].map {
            CanvasElement(frameID: cover.id, rect: CanvasRect(x: 0, y: 0, width: 10, height: 10), kind: .image(path: $0))
        }
        let document = CanvasDocument(frames: [cover], elements: elements)
        let missing = CanvasExportPlan.missingImages(in: cover, of: document, documentPath: fixtureDocumentPath, worktree: root.path)
        #expect(missing == ["gone.png", "../../outside/x.png", "/etc/hosts"])
    }

    @Test func theReportSaysWhereItWroteRelativeToTheWorkspace() throws {
        let plan = try plan([frame("Cover", x: 0)])
        let report = try CanvasExportWriter.write(plan, pictures: pictures(plan))
        #expect(report.title(in: root.resolvingSymlinksInPath().path) == "Exported 1 frame to decks/spring.export")
    }

    @Test func theNoticeCarriesTheToneTheTitleAndEveryProblem() {
        var report = CanvasExportReport(directory: root.appending(path: "decks/spring.export").path, written: ["01-a.png"])
        report.missingFonts = ["Ghost"]
        report.failed = [CanvasExportFailure(frame: "B", reason: "disk full")]
        let notice = CanvasExportNotice.of(report, in: root.path)
        #expect(notice.tone == .warning)
        #expect(notice.title == "Exported 1 frame to decks/spring.export")
        #expect(notice.lines.count == 2)
        #expect(notice.lines.joined().contains("Ghost") && notice.lines.joined().contains("disk full"))
        #expect(CanvasExportNotice.of(CanvasExportRefusal.noFrames).tone == .error)
    }
}
