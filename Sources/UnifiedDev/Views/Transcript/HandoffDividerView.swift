import SwiftUI
import Core

struct HandoffDividerView: View {
    var mark: HandoffMark

    var body: some View {
        HStack(spacing: TranscriptLayout.glyphGap) {
            line
            Text(mark.sentence)
                .font(Typo.caption)
                .foregroundStyle(Palette.textTertiary)
                .lineLimit(1)
                .fixedSize()
            line
        }
        .transcriptRowFrame()
        .accessibilityElement(children: .combine)
    }

    private var line: some View {
        Rectangle()
            .fill(Palette.border)
            .frame(height: Metrics.hairline)
    }
}
