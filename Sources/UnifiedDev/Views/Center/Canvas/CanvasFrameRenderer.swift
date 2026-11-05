import SwiftUI
import AppKit
import Core

struct CanvasFramePicture {
    let png: Data?
    let skippedImages: [String]
}

@MainActor
enum CanvasFrameRenderer {
    static func png(
        frame: CanvasFrame, document: CanvasDocument, documentPath: String, worktree: String, scale: Double = 1
    ) -> Data? {
        picture(frame: frame, document: document, documentPath: documentPath, worktree: worktree, scale: scale).png
    }

    static func picture(
        frame: CanvasFrame, document: CanvasDocument, documentPath: String, worktree: String, scale: Double = 1,
        byteLimit: Int = CanvasRenderPictures.byteLimit
    ) -> CanvasFramePicture {
        let images = CanvasRenderedImages(documentPath: documentPath, worktree: worktree, pixelsPerPoint: scale, byteLimit: byteLimit)
        let view = CanvasFrameView(
            frame: frame,
            elements: document.elements(in: frame.id),
            worktree: worktree,
            documentPath: documentPath,
            renderedImages: images
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation else {
            return CanvasFramePicture(png: nil, skippedImages: images.skipped)
        }
        return CanvasFramePicture(png: NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]), skippedImages: images.skipped)
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
