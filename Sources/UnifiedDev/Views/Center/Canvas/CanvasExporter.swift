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
        for slide in plan.slides {
            if let png = CanvasFrameRenderer.png(frame: slide.frame, document: document, documentPath: path, worktree: worktree) {
                pictures[slide.frame.id] = png
            }
            fonts.formUnion(CanvasFrameRenderer.missingFonts(in: slide.frame, of: document))
            let missing = CanvasExportPlan.missingImages(in: slide.frame, of: document, documentPath: path, worktree: worktree, draws: CanvasImageLoading.draws)
            images += missing.filter { seenImages.insert($0).inserted }
        }
        var report = try CanvasExportWriter.write(plan, pictures: pictures)
        report.missingFonts = fonts.sorted()
        report.missingImages = images
        report.looseElements = document.looseElementCount
        return report
    }
}
