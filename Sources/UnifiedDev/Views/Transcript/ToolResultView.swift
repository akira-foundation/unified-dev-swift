import SwiftUI
import Core

struct ToolResultView: View {
    var text: String
    var isError: Bool

    @State private var showsAll = false

    var body: some View {
        let folded = TextCap.cap(text, lines: TextCap.lineCap)
        let shown = showsAll ? TextCap.cap(text, lines: .max).text : folded.text

        VStack(alignment: .leading, spacing: TranscriptLayout.tight * 2) {
            Text(shown)
                .font(Typo.code)
                .foregroundStyle(isError ? Palette.negative : Palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, TranscriptLayout.block)
                .padding(.vertical, TranscriptLayout.tight)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Palette.border)
                        .frame(width: TranscriptLayout.rule)
                }

            if folded.truncated {
                Button(TextFold.title(isExpanded: showsAll)) { showsAll.toggle() }
                    .linkButton()
                    .font(Typo.caption)
                    .padding(.leading, TranscriptLayout.block)
            }
        }
    }
}
