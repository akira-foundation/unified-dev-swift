import SwiftUI
import Core

struct StartProjectProgress: View {
    var step: RepositoryStartStep
    var isSlow: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing) {
            ForEach(RepositoryStartStep.steps(for: .local), id: \.self) { candidate in
                row(candidate)
            }

            if isSlow {
                Callout(
                    text: step.slowNotice,
                    symbol: "clock.badge.exclamationmark",
                    tone: .warning
                )
            }
        }
    }

    private func row(_ candidate: RepositoryStartStep) -> some View {
        HStack(spacing: Metrics.spacingWide) {
            glyph(candidate)
            Text(candidate.label)
                .font(Typo.label)
                .foregroundStyle(
                    candidate == step ? Palette.textPrimary : Palette.textSecondary
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(candidate.label)
        .accessibilityValue(Self.state(of: candidate, running: step))
    }

    @ViewBuilder
    private func glyph(_ candidate: RepositoryStartStep) -> some View {
        switch candidate {
        case ..<step:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Palette.positive)
                .accessibilityHidden(true)
        case step:
            ProgressView()
                .controlSize(.small)
                .accessibilityHidden(true)
        default:
            Image(systemName: "circle")
                .foregroundStyle(Palette.textTertiary)
                .accessibilityHidden(true)
        }
    }

    private static func state(
        of candidate: RepositoryStartStep,
        running: RepositoryStartStep
    ) -> String {
        switch candidate {
        case ..<running: "Done"
        case running: "Running"
        default: "Not started"
        }
    }
}
