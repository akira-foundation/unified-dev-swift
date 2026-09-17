import SwiftUI

struct TurnFileChip: View {
    var file: TurnFile
    var worktree: String
    var previewsCurrentFile = true

    var body: some View {
        HStack(spacing: TranscriptLayout.tight * 2) {
            Text(file.name)
                .font(Typo.codeSmall)
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)

            DiffStatLabel(additions: file.additions, deletions: file.deletions, compact: true)
        }
        .padding(.horizontal, TranscriptLayout.chipInset)
        .padding(.vertical, Metrics.chipInsetV)
        .background(Palette.hover, in: RoundedRectangle(cornerRadius: Metrics.cornerSmall))
        .fixedSize()
        .background {
            if previewsCurrentFile {
                HoverQuickLook(url: PromptAttachment.sent(path: file.path).url(in: worktree))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .help(display)
    }

    private var display: String { file.display(in: worktree) }

    private var spoken: String {
        var parts = [display]
        if file.additions > 0 { parts.append("\(file.additions) added") }
        if file.deletions > 0 { parts.append("\(file.deletions) removed") }
        return parts.joined(separator: ", ")
    }
}
