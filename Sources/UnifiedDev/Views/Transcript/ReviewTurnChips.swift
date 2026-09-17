import SwiftUI
import Core

struct ReviewTurnChips: View {
    var chips: [ReviewTurnRecord.Chip]
    var home: TranscriptHome

    @Environment(AppModel.self) private var app

    var body: some View {
        ChipFlow(spacing: Metrics.spacingSmall, lineSpacing: Metrics.spacingSmall) {
            ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                Button {
                    open(chip)
                } label: {
                    Chip(text: chip.label, systemImage: "text.bubble")
                        .frame(maxWidth: 300, alignment: .leading)
                }
                .buttonStyle(.plain)
                .help(chip.body)
                .accessibilityLabel("Review comment on \(chip.fileName) \(chip.lineDescription)")
                .accessibilityValue(chip.body)
            }
        }
    }

    private func open(_ chip: ReviewTurnRecord.Chip) {
        guard let id = home.workspaceID, let model = app.existingModel(for: id) else { return }
        FileReview.open(path: chip.filePath, in: model)
    }
}
