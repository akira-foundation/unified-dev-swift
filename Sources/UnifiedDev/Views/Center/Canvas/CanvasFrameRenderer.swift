import SwiftUI
import AppKit
import Core

@MainActor
enum CanvasFrameRenderer {
    static func png(
        frame: CanvasFrame, document: CanvasDocument, documentPath: String, worktree: String, scale: Double = 1
    ) -> Data? {
        let view = CanvasFrameView(
            frame: frame,
            elements: document.elements(in: frame.id),
            worktree: worktree,
            documentPath: documentPath,
            renderedImages: CanvasRenderedImages(documentPath: documentPath, worktree: worktree)
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation else { return nil }
        return NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
    }

    static func missingFonts(in frame: CanvasFrame, of document: CanvasDocument) -> [String] {
        let names = document.elements(in: frame.id).flatMap { element -> [String] in
            switch element.kind {
            case .text(let text), .note(let text): text.runs.map(\.fontName)
            default: []
            }
        }
        return Set(names).filter { NSFont(name: $0, size: 12) == nil }.sorted()
    }
}
