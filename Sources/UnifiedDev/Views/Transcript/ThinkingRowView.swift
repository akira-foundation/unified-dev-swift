import SwiftUI
import Core

struct ThinkingRowView: View {
    var text: String
    var isExpanded = false
    var tokens: Int = 0
    var onToggle: () -> Void = {}

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ExpandableRowHeader(isExpanded: isExpanded, onToggle: onToggle) {
                header
            }

            if isExpanded, !text.isEmpty {
                Text(text)
                    .font(Typo.label)
                    .foregroundStyle(Palette.textSecondary)
                    .proseLeading(Typo.label)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, TranscriptLayout.detailIndent)
                    .padding(.trailing, TranscriptLayout.inset)
                    .padding(.bottom, TranscriptLayout.block)
            }
        }
        .modifier(ExpandableRow(isHovered: isHovered))
        .onHover { isHovered = $0 }
    }

    private var header: some View {
        HStack(spacing: TranscriptLayout.glyphGap) {
            TranscriptGlyph(symbol: "sparkle")

            Text("Thinking")
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)
                .italic()
                .lineLimit(1)
                .transcriptLabelColumn("Thinking", font: Typo.label)

            if !isExpanded {
                Text(ToolPresenter.oneLine(text))
                    .font(Typo.label)
                    .foregroundStyle(Palette.textTertiary)
                    .italic()
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: TranscriptLayout.tight)

            if tokens > 0 {
                Text(Counted.of(tokens, "token"))
                    .font(Typo.micro)
                    .foregroundStyle(Palette.textTertiary)
                    .monospacedDigit()
                    .fixedSize()
            }

            TranscriptDisclosure(isExpanded: isExpanded, isVisible: isHovered)
        }
        .transcriptRowFrame()
    }
}
