import Core
import SwiftUI

struct PinnedQuestion: Equatable {
    var seq: Int
    var summary: String
}

struct PinnedQuestionIndex {
    private var session: SessionID?
    private var scannedRows = 0
    private var questions: [PinnedQuestion] = []

    mutating func update(session: SessionID, rows: [TranscriptRow]) {
        if self.session != session || scannedRows > rows.count {
            self.session = session
            scannedRows = 0
            questions = []
        }

        guard scannedRows < rows.count else { return }
        for row in rows[scannedRows...] where row.kind == .user {
            guard let summary = UserTurnPrompt.summary(in: row.payload) else { continue }
            questions.append(PinnedQuestion(seq: row.seq, summary: summary))
        }
        scannedRows = rows.count
    }

    func latest(atOrBefore seq: Int) -> PinnedQuestion? {
        var low = 0
        var high = questions.count
        while low < high {
            let middle = low + (high - low) / 2
            if questions[middle].seq <= seq {
                low = middle + 1
            } else {
                high = middle
            }
        }
        return low > 0 ? questions[low - 1] : nil
    }
}

struct PinnedQuestionView: View {
    var question: PinnedQuestion
    var onOpen: () -> Void

    static let height: CGFloat = Metrics.barHeight + Metrics.spacingWide

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: Metrics.spacingWide) {
                Image(systemName: "text.bubble")
                    .font(Typo.label)
                    .foregroundStyle(Palette.textSecondary)
                    .accessibilityHidden(true)

                Text(question.summary)
                    .font(Typo.label)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)

                Image(systemName: "chevron.up")
                    .font(Typo.captionEmphasis)
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 20, height: 20)
                    .background(Palette.textSecondary.opacity(0.08), in: Circle())
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Metrics.gutter)
            .frame(maxWidth: .infinity, minHeight: Metrics.barHeight, maxHeight: Metrics.barHeight)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: TranscriptLayout.conversationMeasure)
        .glassEffect(.regular, in: Capsule())
        .pointerStyle(.link)
        .help("Show the full question")
        .accessibilityLabel("Show question: \(question.summary)")
        .padding(.horizontal, ComposerLayout.horizontalInset)
        .padding(.top, Metrics.spacingWide)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
