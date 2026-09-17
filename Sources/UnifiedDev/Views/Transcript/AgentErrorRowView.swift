import SwiftUI
import Core

struct AgentErrorRowView: View {
    var exit: AgentExit
    var isExpanded: Bool
    var onToggle: () -> Void

    @State private var isHovered = false
    @State private var showsAll = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ExpandableRowHeader(isExpanded: isExpanded, onToggle: onToggle) {
                header
            }

            if isExpanded {
                opened
            }
        }
        .modifier(ExpandableRow(isHovered: isHovered))
        .onHover { isHovered = $0 }
    }

    private var header: some View {
        HStack(spacing: TranscriptLayout.glyphGap) {
            TranscriptGlyph(symbol: "exclamationmark.triangle", tint: Palette.negative)

            Text(exit.title)
                .font(Typo.label)
                .foregroundStyle(Palette.negative)
                .lineLimit(1)
                .truncationMode(.tail)
                .transcriptLabelColumn(exit.title, font: Typo.label)

            Text(exit.summary)
                .font(Typo.label)
                .foregroundStyle(Palette.textTertiary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: TranscriptLayout.tight)

            TranscriptDisclosure(isExpanded: isExpanded, isVisible: isHovered)
        }
        .transcriptRowFrame()
    }

    @ViewBuilder
    private var opened: some View {
        VStack(alignment: .leading, spacing: TranscriptLayout.tight * 2) {
            HStack(alignment: .firstTextBaseline, spacing: TranscriptLayout.glyphGap) {
                Image(systemName: "lifepreserver")
                    .font(Typo.caption)
                    .imageScale(.small)
                    .foregroundStyle(Palette.textTertiary)
                    .accessibilityHidden(true)

                Text(exit.advice)
                    .font(Typo.label)
                    .foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            if exit.hasDetail {
                detail
            }
        }
        .padding(.leading, TranscriptLayout.block)
        .padding(.vertical, TranscriptLayout.tight)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Palette.border)
                .frame(width: TranscriptLayout.rule)
        }
        .padding(.leading, TranscriptLayout.detailIndent)
        .padding(.trailing, TranscriptLayout.inset)
        .padding(.bottom, TranscriptLayout.block)
    }

    @ViewBuilder
    private var detail: some View {
        let folded = TextCap.cap(
            exit.detail, lines: Self.detailLines, characters: Self.detailCharacters
        )
        let shown = showsAll
            ? TextCap.cap(exit.detail, lines: .max, characters: TextCap.characterCap).text
            : folded.text

        VStack(alignment: .leading, spacing: TranscriptLayout.tight * 2) {
            Text(shown)
                .font(Typo.code)
                .foregroundStyle(Palette.textSecondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            if folded.truncated {
                Button(TextFold.title(isExpanded: showsAll)) { showsAll.toggle() }
                    .linkButton()
                    .font(Typo.caption)
            }
        }
    }

    private static let detailLines = 40
    private static let detailCharacters = 4_000
}
