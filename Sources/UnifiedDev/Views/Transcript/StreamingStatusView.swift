import SwiftUI

struct StreamingStatusView: View {
    var glyph: String?
    var text: String

    var body: some View {
        HStack(spacing: TranscriptLayout.glyphGap) {
            if let glyph {
                TranscriptGlyph(symbol: glyph, tint: Palette.running)
            } else {
                ActivityDot(isActive: true)
                    .frame(width: TranscriptLayout.glyphWidth)
            }

            Text(text)
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)

            Spacer(minLength: 0)
        }
        .transcriptRowFrame()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}
