import SwiftUI
import Core

struct RateLimitRowView: View {
    var payload: Data

    private var sentence: String? { RateLimitNotice.sentence(forRateLimitEvent: payload) }

    var body: some View {
        if let sentence {
            HStack(spacing: TranscriptLayout.glyphGap) {
                TranscriptGlyph(symbol: "gauge.with.dots.needle.33percent", tint: Palette.warning)

                Text("Rate limit")
                    .font(Typo.label)
                    .foregroundStyle(Palette.textSecondary)
                    .transcriptLabelColumn("Rate limit", font: Typo.label)

                Text(sentence)
                    .font(Typo.label)
                    .foregroundStyle(Palette.textTertiary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .transcriptRowFrame()
        }
    }
}
