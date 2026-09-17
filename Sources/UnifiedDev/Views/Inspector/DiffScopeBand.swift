import SwiftUI
import Core

struct DiffScopeBand: View {
    let scope: DiffScope
    let fileCount: Int
    var note: String?
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
            HStack(spacing: InspectorLayout.gap) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(Typo.micro)
                    .foregroundStyle(Palette.accent)
                    .accessibilityHidden(true)

                Text(scope.badge)
                    .font(Typo.captionEmphasis)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(files)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Button(action: onClear) {
                    Label("Show all changes", systemImage: "xmark")
                }
                .labelStyle(.iconOnly)
                .inspectorBarControl()
                .help("Show all changes")
            }
            .frame(minHeight: InspectorLayout.barHeight - Metrics.spacingSmall * 2)

            if let note {
                Text(note)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, InspectorLayout.inset)
        .padding(.vertical, Metrics.spacingSmall)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.accent.opacity(InspectorLayout.tintOpacity))
    }

    private var files: String {
        "\(fileCount) file\(fileCount == 1 ? "" : "s")"
    }
}
