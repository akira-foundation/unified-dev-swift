import SwiftUI
import Core

struct PullRequestPathView: View {
    var standing: PullRequestStanding
    var showsLabels: Bool
    var onReach: (PullRequestReach) -> Void

    private static let dot: CGFloat = 8
    private static let rule: CGFloat = 16

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(standing.path.enumerated()), id: \.element) { place, step in
                if place > 0 { connector(before: step) }
                stepView(step)
            }
        }
        .frame(height: Self.dot + 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Path from commits to merge")
    }

    private func connector(before step: PullRequestStep) -> some View {
        Capsule()
            .fill(standing.isReached(step) || step == standing.current
                ? Palette.textTertiary
                : Palette.border)
            .frame(width: Self.rule, height: 1)
            .accessibilityHidden(true)
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
        let current = step == standing.current
        let size = current ? Self.dot + 2 : Self.dot
        return HStack(spacing: Metrics.spacingSmall) {
            Circle()
                .fill(current || standing.isReached(step) ? ink(step) : .clear)
                .frame(width: size, height: size)
                .overlay { Circle().strokeBorder(ink(step), lineWidth: 1.5) }

            if current, showsLabels {
                Text(step.label)
                    .font(Typo.micro)
                    .foregroundStyle(standing.tone.pathColour)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .padding(.trailing, current && showsLabels ? Metrics.spacingSmall : 0)
        .contentShape(.rect)
    }

    private func ink(_ step: PullRequestStep) -> Color {
        if step == standing.current { return standing.tone.pathColour }
        return standing.isReached(step) ? Palette.textTertiary : Palette.border
    }
}
