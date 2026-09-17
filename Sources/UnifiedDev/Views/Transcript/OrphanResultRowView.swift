import SwiftUI
import Core

struct OrphanResultRowView: View {
    var result: AgentToolResult

    var body: some View {
        HStack(spacing: TranscriptLayout.glyphGap) {
            TranscriptGlyph(symbol: "arrow.turn.down.right")

            Text(ToolPresenter.oneLine(result.text))
                .font(Typo.label)
                .foregroundStyle(tint)
                .lineLimit(1)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
        .transcriptRowFrame()
    }

    private var tint: Color {
        if result.refusal != nil { return Palette.warning }
        return result.isError ? Palette.negative : Palette.textTertiary
    }
}
