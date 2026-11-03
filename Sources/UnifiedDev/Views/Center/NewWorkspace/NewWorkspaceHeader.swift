import SwiftUI
import Core

struct NewWorkspaceHeader<Chips: View>: View {
    var point: WorkspaceStartingPoint
    var remote: String?
    var isBusy: Bool
    var busyLabel: String
    var roleNote: String?
    @ViewBuilder var chips: Chips

    var body: some View {
        VStack(spacing: Metrics.spacingWide) {
            Text(WorkspaceDraftRows.title)
                .font(Typo.displayHeading)
                .foregroundStyle(Palette.textPrimary)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: Metrics.spacingSmall) {
                Text("in")
                    .font(Typo.label)
                    .foregroundStyle(Palette.textSecondary)
                chips
                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel(busyLabel)
                }
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(.regular)

            VStack(spacing: Metrics.spacingTight) {
                Text(StartingPointLabel.explanation(for: point, remote: remote))
                    .foregroundStyle(Palette.textTertiary)
                    .lineLimit(2)

                if let roleNote {
                    Text(roleNote)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .font(Typo.caption)
            .multilineTextAlignment(.center)
            .frame(maxWidth: TranscriptLayout.conversationMeasure)
        }
        .padding(.horizontal, ComposerLayout.horizontalInset)
    }
}
