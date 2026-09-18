import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Core

struct BackgroundWakeRowView: View {
    var wake: BackgroundWake

    @State private var outputExists = false

    var body: some View {
        HStack(spacing: TranscriptLayout.glyphGap) {
            TranscriptGlyph(symbol: glyph, tint: glyphTint)

            Text(wake.title)
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize()

            if let name = wake.name {
                Chip(text: name)
            }
            if wake.name == nil, !wake.summary.isEmpty {
                Text(wake.summary)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            if let exit = wake.exitLabel {
                Chip(text: exit, tint: exitTint, monospaced: true)
                    .fixedSize()
            }

            Spacer(minLength: 0)

            if outputExists, let file = wake.outputFile {
                Button("Show output") { Self.open(file) }
                    .buttonStyle(.link)
                    .font(Typo.caption)
                    .help(file)
                    .fixedSize()
            }
        }
        .transcriptRowFrame()
        .accessibilityElement(children: .combine)
        .task(id: wake.outputFile) {
            outputExists = wake.outputFile.map { FileManager.default.fileExists(atPath: $0) } ?? false
        }
    }

    private var glyph: String {
        wake.source == .command ? "terminal" : "person.2"
    }

    private var glyphTint: Color {
        wake.outcome == .failed ? Palette.negative : Palette.textTertiary
    }

    private var exitTint: Color {
        switch wake.outcome {
        case .finished: Palette.positive
        case .failed: Palette.negative
        case .stopped: Palette.textSecondary
        }
    }

    private static func open(_ path: String) {
        let url = URL(filePath: path)
        guard let editor = NSWorkspace.shared.urlForApplication(toOpen: .plainText) else {
            NSWorkspace.shared.open(url)
            return
        }
        NSWorkspace.shared.open([url], withApplicationAt: editor, configuration: NSWorkspace.OpenConfiguration())
    }
}
