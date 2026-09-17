import SwiftUI
import Core

struct WorkspaceHoverCardView: View {
    var card: WorkspaceHoverCard

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingWide) {
            branchLine
            title
            footer
        }
        .padding(Metrics.gutter)
        .frame(
            minWidth: HoverCardWidth.minimum,
            maxWidth: HoverCardWidth.ceiling,
            alignment: .leading
        )
        .fixedSize()
        .background(cardBackground)
        .accessibilityHidden(true)
    }

    private var branchLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.spacing) {
            Text(card.branch)
                .font(Typo.codeSmall)
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
                .truncationMode(.head)

            Spacer(minLength: Metrics.spacingSmall)

            if let diff = card.diff {
                DiffStatLabel(additions: diff.additions, deletions: diff.deletions)
            }
        }
    }

    private var title: some View {
        HStack(alignment: .top, spacing: Metrics.spacing) {
            Text(card.title)
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(
                    idealWidth: HoverCardWidth.minimum - Metrics.gutter * 2,
                    maxWidth: .infinity,
                    alignment: .leading
                )

            WorkspaceStatusGlyph(status: card.status)
                .padding(.top, Metrics.spacingTight)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
            HStack(alignment: .firstTextBaseline, spacing: Metrics.spacingSmall) {
                Text(card.state)
                    .font(Typo.captionEmphasis)
                    .foregroundStyle(WorkspaceStatusGlyph.tint(for: card.status))
                    .lineLimit(1)
                    .layoutPriority(1)

                if let detail = card.detail {
                    Text(detail)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 0)
            }

            HStack(alignment: .firstTextBaseline, spacing: Metrics.spacingSmall) {
                if let pullRequest = card.pullRequest {
                    Text(verbatim: "#\(pullRequest.number)")
                        .font(Typo.caption)
                        .monospacedDigit()
                        .foregroundStyle(Palette.textSecondary)
                }

                Spacer(minLength: Metrics.spacingSmall)

                Text(card.age)
                    .font(Typo.caption)
                    .monospacedDigit()
                    .foregroundStyle(Palette.textTertiary)
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
            .fill(.clear)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
                    .stroke(Palette.border, lineWidth: Metrics.outline)
            }
    }
}
