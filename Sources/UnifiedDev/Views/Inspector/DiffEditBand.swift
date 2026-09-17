import SwiftUI
import Core

struct DiffEditBandView: View {
    var region: DiffEditRegion
    @Binding var text: String
    var language: Language
    var status: DiffEditSession.Status
    var width: CGFloat
    var onSave: @MainActor () -> Void
    var onCancel: @MainActor () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private static let maximumLines = 18
    private static let minimumLines = 3
    private static let verticalPadding: CGFloat = 12
    private static let measure: CGFloat = 760

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing) {
            header

            SourceEditor(
                text: $text,
                language: language,
                colorScheme: colorScheme,
                ground: Palette.surface
            )
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerSmall))
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                    .strokeBorder(Palette.border, lineWidth: Metrics.outline)
            }

            if let warning = status.warning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(Typo.caption)
                    .foregroundStyle(isRefused ? Palette.negative : Palette.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }

            buttons
        }
        .frame(maxWidth: Self.measure, alignment: .leading)
        .padding(.horizontal, Metrics.inset)
        .padding(.vertical, Metrics.spacingWide)
        .frame(width: width, alignment: .leading)
        .background(Palette.reviewBand)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Editing \(DiffEditSession.span(of: region))")
    }

    private var header: some View {
        HStack(spacing: Metrics.spacingSmall) {
            Image(systemName: "pencil")
                .font(Typo.micro)
                .imageScale(.small)
            Text("Editing \(DiffEditSession.span(of: region))")
                .font(Typo.caption)
        }
        .foregroundStyle(Palette.textSecondary)
    }

    private var buttons: some View {
        HStack(spacing: Metrics.spacing) {
            Spacer(minLength: 0)

            Button("Cancel", action: onCancel)
                .buttonStyle(.plain)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, Metrics.spacingWide)
                .padding(.vertical, Metrics.spacingSmall)
                .background(Palette.hover, in: RoundedRectangle(cornerRadius: Metrics.cornerSmall))
                .help("Put the lines back as the file has them")

            Button(action: onSave) {
                Text("Save")
                    .font(Typo.captionEmphasis)
                    .foregroundStyle(Palette.selectedEmphasizedText)
                    .padding(.horizontal, Metrics.spacingWide)
                    .padding(.vertical, Metrics.spacingSmall)
                    .background(
                        Palette.controlAccent.opacity(isEdited ? 1 : 0.4),
                        in: RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isEdited)
            .keyboardShortcut("s", modifiers: .command)
            .help("Write these lines to the file (Command S)")
        }
    }

    private var isRefused: Bool {
        if case .failed = status { true } else { false }
    }

    private var isEdited: Bool { region.isEdited(text) }

    private var height: CGFloat {
        let lines = max(1, text.components(separatedBy: "\n").count)
        let shown = min(max(lines, Self.minimumLines), Self.maximumLines)
        return CGFloat(shown) * CodeMetrics.rowHeight + Self.verticalPadding
    }
}
