import SwiftUI
import AppKit
import Core

extension EnvironmentValues {
    @Entry var canvasZoom: Double = 1
}

@MainActor
final class CanvasRenderedImages {
    private let documentPath: String
    private let worktree: String
    private var loaded: [String: NSImage?] = [:]

    init(documentPath: String, worktree: String) {
        self.documentPath = documentPath
        self.worktree = worktree
    }

    func image(_ relative: String) -> NSImage? {
        if let known = loaded[relative] { return known }
        let image = CanvasImageLoading.image(relative, documentPath: documentPath, worktree: worktree)
        loaded[relative] = image
        return image
    }
}

struct CanvasImageView: View {
    let path: String
    let worktree: String
    let documentPath: String
    let style: CanvasStyle
    let size: CanvasSize
    let renderedImages: CanvasRenderedImages?

    var body: some View {
        if let renderedImages {
            CanvasImageFrame(image: renderedImages.image(path).map { Image(nsImage: $0) }, style: style)
        } else {
            CanvasLoadedImageView(path: path, worktree: worktree, documentPath: documentPath, style: style, size: size)
        }
    }
}

private struct CanvasImageFrame: View {
    let image: Image?
    let style: CanvasStyle

    var body: some View {
        if let image {
            Color.clear
                .overlay {
                    image
                        .resizable()
                        .scaledToFill()
                }
                .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius))
        } else {
            RoundedRectangle(cornerRadius: style.cornerRadius)
                .fill(Color.gray.opacity(0.25))
                .overlay { Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary) }
        }
    }
}

private struct CanvasLoadedImageView: View {
    private struct Request: Equatable {
        let path: String
        let need: CanvasImageNeed
    }

    private struct Shown {
        let path: String
        let lease: CanvasImageLease
    }

    private static let revalidation = Duration.seconds(2)

    let path: String
    let worktree: String
    let documentPath: String
    let style: CanvasStyle
    let size: CanvasSize

    @Environment(\.displayScale) private var displayScale
    @Environment(\.canvasZoom) private var zoom
    @State private var shown: Shown?

    private var request: Request {
        Request(path: path, need: CanvasImageNeed(width: size.width, height: size.height, pixelsPerPoint: displayScale * zoom))
    }

    private var image: Image? {
        guard let shown, shown.path == path else { return nil }
        return Image(decorative: shown.lease.image, scale: 1)
    }

    var body: some View {
        CanvasImageFrame(image: image, style: style)
            .task(id: request) { await keepLoaded(request) }
    }

    private func keepLoaded(_ request: Request) async {
        while !Task.isCancelled {
            let lookup = await CanvasImageLoading.cache.lookup(
                request.path, documentPath: documentPath, worktree: worktree, need: request.need
            )
            guard !Task.isCancelled else { return }
            apply(lookup, for: request.path)
            try? await Task.sleep(for: Self.revalidation)
        }
    }

    private func apply(_ lookup: CanvasImageLookup, for path: String) {
        switch lookup {
        case .ready(let lease):
            guard shown?.path != path || !lease.isSamePicture(as: shown?.lease) else { return }
            shown = Shown(path: path, lease: lease)
        case .unavailable:
            shown = nil
        case .overBudget:
            if shown?.path != path { shown = nil }
        }
    }
}
