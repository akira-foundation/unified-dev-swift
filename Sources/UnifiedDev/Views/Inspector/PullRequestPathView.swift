import SwiftUI
import Core

struct PullRequestPathView: View {
    var standing: PullRequestStanding
    var showsLabels: Bool
    var onReach: (PullRequestReach) -> Void

    private static let rule: CGFloat = 3

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.spacingSmall) {
            ForEach(standing.path, id: \.self) { step in
                stepView(step)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Path from commits to merge")
    }

    @ViewBuilder
    private func stepView(_ step: PullRequestStep) -> some View {
        if let reach = standing.reach(of: step) {
            Button { onReach(reach) } label: { mark(step) }
                .buttonStyle(.plain)
                .help(standing.announcement(of: step) ?? step.label)
                .accessibilityLabel(step.label)
                .accessibilityHint(standing.announcement(of: step) ?? "")
        } else {
            mark(step)
                .accessibilityLabel(step.label)
        }
    }

    private func mark(_ step: PullRequestStep) -> some View {
        VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
            Capsule()
                .fill(ink(step))
                .frame(height: Self.rule)

            if showsLabels {
                Text(step.label)
                    .font(Typo.micro)
                    .foregroundStyle(step == standing.current ? ink(step) : Palette.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
    }

    private func ink(_ step: PullRequestStep) -> Color {
        guard let current = standing.current else { return Palette.border }
        if step == current { return standing.tone.pathColour }
        guard let reached = standing.path.firstIndex(of: current),
              let mine = standing.path.firstIndex(of: step), mine < reached
        else { return Palette.border }
        return Palette.textTertiary
    }
}
