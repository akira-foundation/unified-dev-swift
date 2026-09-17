import SwiftUI
import Core

struct ReviewCommentChip: View {
    var comment: ReviewComment
    var onRemove: @MainActor () -> Void
    var onOpen: @MainActor () -> Void

    @State private var isHovered = false

    private static let slot: CGFloat = AttachmentChip.slot
    private static let maxNameWidth: CGFloat = SlashCommandChip.maxNameWidth

    var body: some View {
        HStack(spacing: Metrics.spacingSmall) {
            leading

            Text(ReviewCommentSummary.chip(for: comment))
                .font(Typo.codeSmall)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: Self.maxNameWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Metrics.spacing)
        .frame(height: AttachmentChip.height)
        .fixedSize(horizontal: true, vertical: false)
        .background {
            RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                .fill(isHovered ? Palette.hover : Palette.surfaceRaised)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                .strokeBorder(Palette.border, lineWidth: Metrics.outline)
        }
        .contentShape(RoundedRectangle(cornerRadius: Metrics.cornerSmall))
        .onTapGesture(perform: onOpen)
        .onHover { isHovered = $0 }
        .help(comment.body)
        .contextMenu {
            Button("Show in the diff", action: onOpen)
            Divider()
            Button("Remove the comment", action: onRemove)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Review comment on \(ReviewCommentSummary.chip(for: comment))")
        .accessibilityValue(comment.body)
        .accessibilityAction(named: "Remove", onRemove)
        .accessibilityAction(named: "Show in the diff", onOpen)
    }

    @ViewBuilder
    private var leading: some View {
        if isHovered {
            ChipRemoveButton(diameter: Self.slot, label: "Remove the comment", action: onRemove)
        } else {
            Image(systemName: "text.bubble")
                .resizable()
                .scaledToFit()
                .frame(width: Self.slot, height: Self.slot)
                .foregroundStyle(Palette.textSecondary)
                .accessibilityHidden(true)
        }
    }
}
