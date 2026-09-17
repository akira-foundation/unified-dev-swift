import SwiftUI
import Core

struct ToolRefusalView: View {
    var refusal: ToolRefusal
    var reason: String

    private var sentence: String {
        reason.isEmpty ? refusal.summary : reason
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TranscriptLayout.tight * 2) {
            HStack(alignment: .firstTextBaseline, spacing: TranscriptLayout.glyphGap) {
                Image(systemName: "hand.raised")
                    .font(Typo.caption)
                    .imageScale(.small)
                    .foregroundStyle(Palette.warning)
                    .accessibilityHidden(true)

                Text(sentence)
                    .font(Typo.label)
                    .foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let remedy = refusal.remedy {
                Text(remedy)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, TranscriptLayout.glyphWidth + TranscriptLayout.glyphGap)
            }
        }
        .padding(.leading, TranscriptLayout.block)
        .padding(.vertical, TranscriptLayout.tight)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Palette.border)
                .frame(width: TranscriptLayout.rule)
        }
    }
}
