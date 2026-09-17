import SwiftUI
import Core

struct DetailCodeBlock: View {
    var text: String
    var tint: Color = Palette.surfaceSunken
    var copyTitle: String = "Copy"

    var body: some View {
        DetailBlock(text: text, font: Typo.code, tint: tint, copyTitle: copyTitle)
    }
}

struct DetailProseBlock: View {
    var text: String
    var copyTitle: String = "Copy"

    var body: some View {
        DetailBlock(
            text: text, font: Typo.body, tint: Palette.surfaceSunken, copyTitle: copyTitle
        )
    }
}

private struct DetailBlock: View {
    var text: String
    var font: ScaledFont
    var tint: Color
    var copyTitle: String

    @State private var showsAll = false
    @State private var isHovered = false

    var body: some View {
        if !text.isEmpty {
            let folded = TextCap.cap(text, lines: TextCap.lineCap)
            let shown = showsAll ? TextCap.cap(text, lines: .max).text : folded.text

            VStack(alignment: .leading, spacing: TranscriptLayout.tight * 2) {
                HStack(alignment: .top, spacing: TranscriptLayout.glyphGap) {
                    Text(shown)
                        .font(font)
                        .foregroundStyle(Palette.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    CopyButton(text: text, title: copyTitle, isVisible: isHovered)
                }
                .padding(TranscriptLayout.inset)
                .background(tint, in: RoundedRectangle(cornerRadius: Metrics.corner))
                .onHover { isHovered = $0 }

                if folded.truncated {
                    Button(TextFold.title(isExpanded: showsAll)) { showsAll.toggle() }
                        .linkButton()
                        .font(Typo.caption)
                }
            }
        }
    }
}
