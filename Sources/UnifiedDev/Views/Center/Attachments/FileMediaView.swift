import SwiftUI
import UniformTypeIdentifiers
import Core

struct FileMediaView: View {
    var worktree: String
    var path: String

    @State private var width: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            Hairline()

            GeometryReader { proxy in
                AttachmentPreview(
                    url: url,
                    maxWidth: max(proxy.size.width - Metrics.pane * 2, 1),
                    maxHeight: max(proxy.size.height - Metrics.pane * 2, 1)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var header: some View {
        HStack(spacing: InspectorLayout.gap) {
            FilePathLabel(path: path, width: width)

            Spacer(minLength: InspectorLayout.tight)

            Button("Reveal in Finder", systemImage: "folder") {
                Reveal.inFinder(url.path)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .controlSize(.small)
            .help("Show \(filename) in Finder")
        }
        .padding(.horizontal, InspectorLayout.inset)
        .frame(height: InspectorLayout.barHeight)
        .background(Palette.surfaceSunken)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .help(path)
    }

    private var url: URL {
        URL(filePath: (worktree as NSString).appendingPathComponent(path))
    }

    private var filename: String { (path as NSString).lastPathComponent }

    static func isMedia(path: String) -> Bool {
        guard let type = UTType(filenameExtension: (path as NSString).pathExtension) else {
            return false
        }
        if type.conforms(to: .text) || type.conforms(to: .sourceCode) { return false }
        return [UTType.image, .pdf, .audiovisualContent, .archive, .font]
            .contains { type.conforms(to: $0) }
    }
}
