import SwiftUI
import Core

struct ImageDiffView: View {
    let filename: String
    let sides: ImageDiffSides
    let isEmbedded: Bool

    static let embeddedHeight: CGFloat = 480

    var body: some View {
        HStack(alignment: .top, spacing: InspectorLayout.gap) {
            ForEach(Array(sides.columns.enumerated()), id: \.offset) { _, column in
                ImageDiffColumnView(filename: filename, column: column)
            }
        }
        .padding(InspectorLayout.inset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: isEmbedded ? Self.embeddedHeight : nil)
    }
}

private struct ImageDiffColumnView: View {
    let filename: String
    let column: ImageDiffColumn

    @State private var decoded: Decoded = .waiting

    private enum Decoded {
        case waiting
        case failed
        case image(CGImage)
    }

    var body: some View {
        VStack(spacing: InspectorLayout.tight) {
            if let title = column.title {
                Text(title).font(Typo.caption).foregroundStyle(Palette.textSecondary)
            }
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: column.side) { await decode() }
    }

    @ViewBuilder
    private var content: some View {
        switch column.side {
        case .absent:
            EmptyView()
        case .tooLarge:
            notice("Too large to show")
        case .image:
            switch decoded {
            case .waiting:
                ProgressView().controlSize(.small)
            case .failed:
                notice("Cannot draw this image")
            case let .image(image):
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: CGFloat(image.width), maxHeight: CGFloat(image.height))
                    .accessibilityLabel(Text(column.title.map { "\($0): \(filename)" } ?? filename))
            }
        }
    }

    private func notice(_ text: String) -> some View {
        Text(text).font(Typo.caption).foregroundStyle(Palette.textSecondary)
    }

    private func decode() async {
        guard case let .image(data) = column.side else { return }
        let image = await Task.detached(priority: .userInitiated) { ImageDiff.decode(data) }.value
        guard !Task.isCancelled else { return }
        decoded = image.map(Decoded.image) ?? .failed
    }
}
