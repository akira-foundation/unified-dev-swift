import SwiftUI
import Core

struct AgentQuestionClosedCard: View {
    var digests: [AgentQuestionDigest]
    var settledText: String
    var isHovered: Bool

    private var hasAnswers: Bool { digests.contains { $0.isAnswered } }

    private var drawn: [AgentQuestionDigest] {
        hasAnswers ? digests : Array(digests.prefix(1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingTight) {
            ForEach(Array(drawn.enumerated()), id: \.element.id) { index, digest in
                line(digest, isFirst: index == 0, forcesSettledText: !hasAnswers)
            }

            if drawn.isEmpty { settled }
        }
    }

    private var settled: some View {
        HStack(alignment: .firstTextBaseline, spacing: TranscriptLayout.glyphGap) {
            Image(systemName: "questionmark.bubble.fill")
                .font(Typo.caption)
                .imageScale(.small)
                .foregroundStyle(Palette.textTertiary)
                .frame(width: TranscriptLayout.glyphWidth)
                .accessibilityHidden(true)

            Text(settledText)
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: TranscriptLayout.tight)

            TranscriptDisclosure(isExpanded: false, isVisible: isHovered)
        }
    }

    private func line(
        _ digest: AgentQuestionDigest, isFirst: Bool, forcesSettledText: Bool
    ) -> some View {
        let isAnswered = digest.isAnswered && !forcesSettledText

        return HStack(alignment: .firstTextBaseline, spacing: TranscriptLayout.glyphGap) {
            Image(systemName: "questionmark.bubble.fill")
                .font(Typo.caption)
                .imageScale(.small)
                .foregroundStyle(Palette.textTertiary)
                .frame(width: TranscriptLayout.glyphWidth)
                .opacity(isFirst ? 1 : 0)
                .accessibilityHidden(true)

            Text(digest.question)
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)

            answer(digest, isAnswered: isAnswered)

            Spacer(minLength: TranscriptLayout.tight)

            TranscriptDisclosure(isExpanded: false, isVisible: isHovered)
                .opacity(isFirst ? 1 : 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isAnswered ? digest.spoken : "\(digest.question) \(settledText)")
    }

    @ViewBuilder
    private func answer(_ digest: AgentQuestionDigest, isAnswered: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.spacingTight) {
            if isAnswered {
                Image(systemName: digest.isTyped ? "pencil" : "checkmark")
                    .font(Typo.micro)
                    .foregroundStyle(Palette.accent)
                    .accessibilityHidden(true)
            }

            Text(isAnswered ? digest.answerText : settledText)
                .font(Typo.labelEmphasis)
                .foregroundStyle(isAnswered ? Palette.textPrimary : Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .layoutPriority(1)
    }
}
