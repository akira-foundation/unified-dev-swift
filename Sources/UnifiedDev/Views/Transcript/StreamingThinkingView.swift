import SwiftUI
import Core

struct StreamingThinkingView: View {
    var text: String
    var tokens: Int

    private static let tailLimit = 600

    private var tail: String {
        guard text.utf8.count > Self.tailLimit else { return text }
        let kept = text.suffix(Self.tailLimit)
        guard kept.startIndex != text.startIndex else { return text }
        return "\u{2026}" + String(kept)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Text(tail)
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)
                .italic()
                .proseLeading(Typo.label)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, TranscriptLayout.detailIndent)
                .padding(.trailing, TranscriptLayout.inset)
                .padding(.bottom, TranscriptLayout.block)
        }
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

            if tokens > 0 {
                Text(Counted.of(tokens, "token"))
                    .font(Typo.micro)
                    .foregroundStyle(Palette.textTertiary)
                    .monospacedDigit()
                    .fixedSize()
            }

            Spacer(minLength: TranscriptLayout.tight)
        }
        .transcriptRowFrame()
    }
}
