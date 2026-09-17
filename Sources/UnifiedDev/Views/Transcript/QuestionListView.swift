import SwiftUI
import Core

struct QuestionListView: View {
    var questions: [JSONValue]

    var body: some View {
        VStack(alignment: .leading, spacing: TranscriptLayout.inset) {
            ForEach(Array(questions.enumerated()), id: \.offset) { _, question in
                VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
                    Text(question["question"]?.stringValue ?? "")
                        .font(Typo.bodyEmphasis)
                        .foregroundStyle(Palette.textPrimary)

                    ForEach(Array((question["options"]?.arrayValue ?? []).enumerated()), id: \.offset) { _, option in
                        HStack(alignment: .firstTextBaseline, spacing: TranscriptLayout.glyphGap) {
                            Image(systemName: "circle")
                                .font(Typo.label)
                                .imageScale(.small)
                                .foregroundStyle(Palette.textTertiary)
                                .accessibilityHidden(true)

                            Text(option["label"]?.stringValue ?? "")
                                .font(Typo.label)
                                .foregroundStyle(Palette.textSecondary)
                        }
                    }
                }
            }
        }
    }
}
