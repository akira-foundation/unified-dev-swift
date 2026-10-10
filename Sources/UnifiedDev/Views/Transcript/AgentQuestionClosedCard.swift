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

    private func line(
        _ digest: AgentQuestionDigest, isFirst: Bool, forcesSettledText: Bool
    ) -> some View {
        let isAnswered = digest.isAnswered && !forcesSettledText

        return HStack(alignment: .firstTextBaseline, spacing: TranscriptLayout.glyphGap) {
            glyph.opacity(isFirst ? 1 : 0)

            Text(digest.question)
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)

            if !isAnswered {
                Text(settledText)
                    .font(Typo.label)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: TranscriptLayout.tight)

            mark(digest, isAnswered: isAnswered)

            TranscriptDisclosure(isExpanded: false, isVisible: isHovered)
                .opacity(isFirst ? 1 : 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isAnswered ? digest.spoken : "\(digest.question) \(settledText)")
    }

    @ViewBuilder
    private func mark(_ digest: AgentQuestionDigest, isAnswered: Bool) -> some View {
        Image(systemName: digest.isTyped ? "pencil" : "checkmark")
            .font(Typo.micro)
            .foregroundStyle(Palette.accent)
            .frame(width: TranscriptLayout.glyphWidth)
            .opacity(isAnswered ? 1 : 0)
            .accessibilityHidden(true)
    }

    private var glyph: some View {
        Image(systemName: "questionmark.bubble.fill")
            .font(Typo.caption)
            .imageScale(.small)
            .foregroundStyle(Palette.textTertiary)
            .frame(width: TranscriptLayout.glyphWidth)
            .accessibilityHidden(true)
    }

    private var settled: some View {
        HStack(alignment: .firstTextBaseline, spacing: TranscriptLayout.glyphGap) {
            glyph

            Text(settledText)
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: TranscriptLayout.tight)

            TranscriptDisclosure(isExpanded: false, isVisible: isHovered)
        }
    }
}
