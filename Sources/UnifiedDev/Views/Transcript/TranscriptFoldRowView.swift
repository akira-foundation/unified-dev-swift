import Core
import SwiftUI

struct TranscriptFoldRowView: View {
    var hiddenCount: Int
    var showsMore: Bool
    var isExpanded: Bool
    var isNested = false
    var onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        ExpandableRowHeader(isExpanded: isExpanded, onToggle: onToggle) {
            HStack(spacing: Metrics.spacingSmall) {
                TranscriptDisclosure(isExpanded: isExpanded, isVisible: true)
                    .frame(width: TranscriptLayout.disclosureWidth)

                HStack(spacing: TranscriptLayout.glyphGap) {
                    TranscriptGlyph(symbol: "circle")
                        .environment(\.transcriptFoldCount, hiddenCount)

                    Text("actions")
                        .font(Typo.label)
                        .foregroundStyle(Palette.textTertiary)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .transcriptRowFrame()
            }
        }
        .accessibilityLabel("\(hiddenCount) actions")
        .modifier(ExpandableRow(isHovered: isHovered))
        .onHover { isHovered = $0 }
        .padding(.leading, isNested ? TranscriptLayout.nestIndent : 0)
        .overlay(alignment: .leading) {
            if isNested {
                Rectangle()
                    .fill(Palette.border)
                    .frame(width: Metrics.hairline)
                    .padding(.leading, TranscriptLayout.inset)
            }
        }
    }
}
