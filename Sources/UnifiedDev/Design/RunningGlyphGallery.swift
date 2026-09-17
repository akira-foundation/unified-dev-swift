import SwiftUI
import QuartzCore
import Core

struct RunningGlyphGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("Running mark")
                .font(Typo.title)

            row(
                "In a row, unselected",
                background: Palette.surface,
                onSelection: false
            )
            row(
                "In a row, selected",
                background: Palette.selectedEmphasized,
                onSelection: true
            )

            HStack(alignment: .top, spacing: 32) {
                enlarged("Moving", onSelection: false)
                enlarged("Selected", onSelection: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Against the marks it used to share a colour with")
                    .font(Typo.label)
                    .foregroundStyle(Palette.textSecondary)
                HStack(alignment: .top, spacing: 24) {
                    named("Running") { WorkspaceRunningGlyph() }
                    named("Unread") { WorkspaceStatusGlyph(status: .unread) }
                    named("Pull request") { WorkspaceStatusGlyph(status: .pullRequestOpen) }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("The mark it was mistaken for")
                    .font(Typo.label)
                    .foregroundStyle(Palette.textSecondary)
                HStack(alignment: .top, spacing: 24) {
                    named("Running") { WorkspaceRunningGlyph() }
                    named("No changes") { WorkspaceStatusGlyph(status: .clean) }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("The same pair, selected")
                    .font(Typo.label)
                    .foregroundStyle(Palette.textSecondary)
                HStack(alignment: .top, spacing: 24) {
                    named("Running") { WorkspaceRunningGlyph(isOnSelection: true) }
                    named("No changes") {
                        WorkspaceStatusGlyph(status: .clean, isOnSelection: true)
                    }
                }
                .padding(8)
                .background(Palette.selectedEmphasized)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Four rows, one heartbeat")
                    .font(Typo.label)
                    .foregroundStyle(Palette.textSecondary)
                ForEach(0..<4, id: \.self) { index in
                    mockRow(name: "workspace \(index + 1)", background: Palette.surface, onSelection: false)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func row(_ title: String, background: Color, onSelection: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)
            mockRow(name: "Review PR 168", background: background, onSelection: onSelection)
        }
    }

    private func mockRow(name: String, background: Color, onSelection: Bool) -> some View {
        HStack(spacing: 8) {
            WorkspaceRunningGlyph(isOnSelection: onSelection)
                .frame(width: Metrics.glyph, height: Metrics.glyph)
            Text(name)
                .font(Typo.body)
                .foregroundStyle(
                    onSelection ? Palette.selectedEmphasizedText : Palette.textPrimary
                )
            Spacer()
        }
        .padding(.horizontal, 8)
        .frame(width: 260, height: 32)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func named<Mark: View>(_ title: String, @ViewBuilder mark: () -> Mark) -> some View {
        VStack(spacing: 6) {
            mark()
                .frame(width: Metrics.glyph, height: Metrics.glyph)
            mark()
                .frame(width: Metrics.glyph, height: Metrics.glyph)
                .scaleEffect(4, anchor: .center)
                .frame(width: Metrics.glyph * 4, height: Metrics.glyph * 4)
            Text(title)
                .font(Typo.micro)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private func enlarged(_ title: String, onSelection: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)
            WorkspaceRunningGlyph(isOnSelection: onSelection)
                .frame(width: Metrics.glyph, height: Metrics.glyph)
                .scaleEffect(8, anchor: .center)
                .frame(width: Metrics.glyph * 8, height: Metrics.glyph * 8)
                .background(onSelection ? Palette.selectedEmphasized : Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

extension Gallery {
    static let runningGlyph = Gallery(
        name: "running-glyph",
        title: "Running mark",
        size: CGSize(width: 700, height: 1240),
        needsFocus: false,
        view: { _ in AnyView(RunningGlyphGallery()) }
    )
}
