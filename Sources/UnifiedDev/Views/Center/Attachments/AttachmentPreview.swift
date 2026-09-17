import SwiftUI
import AppKit
import Core
import QuickLookThumbnailing
import UniformTypeIdentifiers

struct AttachmentPreview: View {
    var url: URL
    var maxWidth: CGFloat
    var maxHeight: CGFloat

    private enum Phase {
        case loading
        case ready(CGImage, scale: CGFloat)
        case text([String], truncated: Bool)
        case unavailable
        case missing
    }

    @State private var phase: Phase = .loading

    private static let minSide: CGFloat = 120

    private static let noteGlyph: CGFloat = 28
    private static let noteIcon: CGFloat = 48

    var body: some View {
        content
            .frame(maxWidth: maxWidth, maxHeight: maxHeight)
            .task(id: LoadID(path: url.path, width: maxWidth, height: maxHeight)) { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            ProgressView()
                .controlSize(.small)
                .frame(width: Self.minSide, height: Self.minSide)
        case .ready(let image, let scale):
            Image(image, scale: scale, label: Text("Preview of \(url.lastPathComponent)"))
        case .text(let lines, let truncated):
            SourceLines(lines: lines, truncated: truncated)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("The first lines of \(url.lastPathComponent)")
        case .unavailable:
            unpreviewable
        case .missing:
            note(
                glyph: "doc.questionmark",
                title: "\(url.lastPathComponent) is gone",
                detail: "It is no longer on disk."
            )
        }
    }

    private var unpreviewable: some View {
        note(
            glyph: nil,
            title: url.lastPathComponent,
            detail: [kindDescription, sizeDescription].compactMap { $0 }.joined(separator: " · ")
        )
    }

    private func note(glyph: String?, title: String, detail: String) -> some View {
        VStack(spacing: Metrics.spacing) {
            if let glyph {
                Image(systemName: glyph)
                    .font(.system(size: Self.noteGlyph))
                    .foregroundStyle(Palette.textTertiary)
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: Self.noteIcon, height: Self.noteIcon)
            }

            Text(title)
                .font(Typo.bodyEmphasis)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            if !detail.isEmpty {
                Text(detail)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .padding(Metrics.pane)
        .frame(minWidth: Self.minSide * 2, minHeight: Self.minSide)
    }

    private var kindDescription: String? {
        UTType(filenameExtension: url.pathExtension)?.localizedDescription
    }

    private var sizeDescription: String? {
        let bytes = AttachmentFiles.byteCount(of: url.path)
        guard bytes > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private struct LoadID: Hashable {
        var path: String
        var width: CGFloat
        var height: CGFloat
    }

    private func load() async {
        guard FileManager.default.fileExists(atPath: url.path) else {
            phase = .missing
            return
        }

        if !FileMediaView.isMedia(path: url.path),
           AttachmentFiles.byteCount(of: url.path) <= SourceHead.byteLimit {
            let path = url.path
            let head = await Task.detached(priority: .utility) { SourceHead.read(path) }.value
            guard !Task.isCancelled else { return }
            if let head, !head.lines.isEmpty {
                phase = .text(head.lines, truncated: head.truncated)
                return
            }
        }

        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: max(maxWidth, Self.minSide), height: max(maxHeight, Self.minSide)),
            scale: scale,
            representationTypes: .thumbnail
        )

        do {
            let representation = try await QLThumbnailGenerator.shared
                .generateBestRepresentation(for: request)
            guard !Task.isCancelled else { return }
            phase = .ready(representation.cgImage, scale: scale)
        } catch {
            guard !Task.isCancelled else { return }
            phase = .unavailable
        }
    }
}

struct SourceLines: View {
    var lines: [String]
    var truncated: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            if truncated {
                Text("\u{2026}")
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .font(Typo.codeSmall)
        .foregroundStyle(Palette.textPrimary)
        .textSelection(.disabled)
    }
}

enum SourceHead {
    static let byteLimit = 512 * 1024

    static func read(_ path: String) -> (lines: [String], truncated: Bool)? {
        guard let data = FileManager.default.contents(atPath: path),
              let text = String(data: data, encoding: .utf8)
        else { return nil }
        return TextHead.head(of: text)
    }
}
