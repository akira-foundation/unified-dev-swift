import SwiftUI
import UniformTypeIdentifiers
import Core

struct AttachmentCardOverlay: View {
    var attachment: PromptAttachment?
    var worktree: String
    var availableWidth: CGFloat

    var body: some View {
        if let attachment {
            AttachmentCard(
                attachment: attachment, worktree: worktree, availableWidth: availableWidth
            )
        }
    }
}

struct AttachmentCard: View {
    var attachment: PromptAttachment
    var worktree: String
    var availableWidth: CGFloat

    private static var maxWidth: CGFloat { HoverCardWidth.ceiling }
    private static let maxHeight: CGFloat = 380

    var body: some View {
        MenuPanel {
            VStack(alignment: .leading, spacing: 0) {
                AttachmentPreview(url: url, maxWidth: width, maxHeight: Self.maxHeight)
                    .frame(maxWidth: .infinity, alignment: isImage ? .center : .leading)
                    .padding(Metrics.inset)

                if let comment = attachment.imageComment {
                    Hairline()
                    HStack(alignment: .firstTextBaseline, spacing: Metrics.spacing) {
                        Image(systemName: "text.bubble")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                        Text(comment.body)
                            .font(Typo.body)
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(8)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(Metrics.inset)
                    .background(Palette.reviewBand)
                }

                if !isImage {
                    Hairline()

                    Text(attachment.path)
                        .font(Typo.codeSmall)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Metrics.inset)
                        .padding(.vertical, Metrics.spacing)
                }
            }
        }
        .frame(maxWidth: width + Metrics.inset * 2)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var url: URL { attachment.url(in: worktree) }

    private var width: CGFloat {
        max(min(availableWidth - Metrics.gutter * 2, Self.maxWidth), 160)
    }

    private var isImage: Bool {
        UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
    }
}
