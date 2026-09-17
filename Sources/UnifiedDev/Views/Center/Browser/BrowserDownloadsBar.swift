import SwiftUI
import Core

struct BrowserDownloadsBar: View {
    var downloads: [BrowserDownloadItem]
    var clear: @MainActor () -> Void

    private static let shown = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(downloads.suffix(Self.shown)) { download in
                row(download)
            }
        }
        .background(Palette.surfaceSunken)
        .overlay(alignment: .bottom) { Hairline() }
    }

    private func row(_ download: BrowserDownloadItem) -> some View {
        HStack(spacing: Metrics.spacingWide) {
            Image(systemName: glyph(download))
                .imageScale(.small)
                .foregroundStyle(tint(download))
                .frame(width: Metrics.glyph)

            VStack(alignment: .leading, spacing: 0) {
                Text(download.name.isEmpty ? "Starting" : download.name)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(download.status)
                    .font(Typo.micro)
                    .foregroundStyle(Palette.textTertiary)
                    .lineLimit(1)
            }

            if let fraction = download.fraction {
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                    .frame(width: 80)
            }

            Spacer(minLength: 0)

            if download.state == .finished, let destination = download.destination {
                Button("Show in Finder") { Reveal.inFinder(destination.path) }
                    .buttonStyle(.glass)
                    .font(Typo.micro)
            }

            Button {
                clear()
            } label: {
                Label("Close", systemImage: "xmark")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(Palette.textSecondary)
            }
            .buttonStyle(.glass)
            .help("Stop showing what this page has downloaded")
        }
        .padding(.horizontal, Metrics.spacingWide)
        .frame(height: Metrics.barHeight)
    }

    private func glyph(_ download: BrowserDownloadItem) -> String {
        switch download.state {
        case .running: "arrow.down.circle"
        case .finished: "checkmark.circle"
        case .failed: "exclamationmark.triangle"
        }
    }

    private func tint(_ download: BrowserDownloadItem) -> Color {
        switch download.state {
        case .running: Palette.textSecondary
        case .finished: Palette.positive
        case .failed: Palette.negative
        }
    }
}
