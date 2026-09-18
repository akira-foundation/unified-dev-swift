import SwiftUI

struct NewWorkspaceProblem: View {
    var sentence: String

    var body: some View {
        Label(sentence, systemImage: "exclamationmark.triangle")
            .font(Typo.caption)
            .foregroundStyle(Palette.negative)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: TranscriptLayout.conversationMeasure, alignment: .leading)
            .padding(.horizontal, ComposerLayout.horizontalInset)
            .accessibilityElement(children: .combine)
    }
}
