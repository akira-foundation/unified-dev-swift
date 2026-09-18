import SwiftUI
import Core

struct NewWorkspaceHeader<Chips: View>: View {
    var point: WorkspaceStartingPoint
    var remote: String?
    var isBusy: Bool
    var busyLabel: String
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
            .controlSize(.large)

            Text(StartingPointLabel.explanation(for: point, remote: remote))
                .font(Typo.caption)
                .foregroundStyle(Palette.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: TranscriptLayout.conversationMeasure)
        }
        .padding(.horizontal, ComposerLayout.horizontalInset)
    }
}
