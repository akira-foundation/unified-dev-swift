import SwiftUI
import Core

struct CodeRunLine: Equatable {
    var text: String
    var carry: LexState = LexState()
    var emphasis: [Range<String.Index>] = []
    var emphasisColor: Color = .clear
}

struct CodeRunText: View, Equatable {
    var lines: [CodeRunLine]
    var language: Language

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.language == rhs.language && lhs.lines == rhs.lines
    }

    var body: some View {
        Text(joined)
            .font(CodeMetrics.measuredFont)
            .lineSpacing(CodeMetrics.rowSpacing)
            .textSelection(.enabled)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.vertical, CodeMetrics.rowSpacing / 2)
    }

    private var joined: AttributedString {
        var output = AttributedString()
        for (offset, line) in lines.enumerated() {
            if offset > 0 { output += AttributedString("\n") }
            output += CodeText.attributed(
                line: line.text,
                language: language,
                carry: line.carry,
                emphasis: line.emphasis,
                emphasisColor: line.emphasisColor
            )
        }
        return output
    }
}
