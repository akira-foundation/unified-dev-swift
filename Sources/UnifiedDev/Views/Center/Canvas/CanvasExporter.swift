import Foundation
import Core

@MainActor
enum CanvasExporter {
    static func export(document: CanvasDocument, path: String, worktree: String) throws -> CanvasExportReport {
        let plan = try CanvasExportPlan.make(document: document, path: path, worktree: worktree)
        var pictures: [CanvasFrameID: Data] = [:]
        var fonts: Set<String> = []
        var images: [String] = []
        var seenImages: Set<String> = []
        var skipped: [String] = []
        for slide in plan.slides {
            let picture = CanvasFrameRenderer.picture(frame: slide.frame, document: document, documentPath: path, worktree: worktree)
            if let png = picture.png { pictures[slide.frame.id] = png }
            skipped += picture.skippedImages.filter { !skipped.contains($0) }
            fonts.formUnion(CanvasFrameRenderer.missingFonts(in: slide.frame, of: document))
            let missing = CanvasExportPlan.missingImages(in: slide.frame, of: document, documentPath: path, worktree: worktree, draws: CanvasImageLoading.draws)
            images += missing.filter { seenImages.insert($0).inserted }
        }
        var report = try CanvasExportWriter.write(plan, pictures: pictures)
        report.missingFonts = fonts.sorted()
        report.missingImages = images
        report.skippedImages = skipped
        report.looseElements = document.looseElementCount
        return report
    }
}
