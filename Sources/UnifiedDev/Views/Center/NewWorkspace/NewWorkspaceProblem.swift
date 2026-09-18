import SwiftUI

struct NewWorkspaceProblem: View {
    var sentence: String

    var body: some View {
        Label(sentence, systemImage: "exclamationmark.triangle")
            .font(Typo.caption)
            .foregroundStyle(Palette.negative)
            .frame(maxWidth: TranscriptLayout.conversationMeasure, alignment: .leading)
            .layoutPriority(1)
            .padding(.horizontal, ComposerLayout.horizontalInset)
            .accessibilityElement(children: .combine)
    }
}
