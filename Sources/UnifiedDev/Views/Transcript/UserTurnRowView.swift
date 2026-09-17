import SwiftUI
import Core

struct UserTurnRowView: View {
    var text: String
    var attachments: [String] = []
    var reviewChips: [ReviewTurnRecord.Chip] = []
    var home: TranscriptHome

    @Environment(AppModel.self) private var app
    @Environment(\.markdownLinkActions) private var linkActions
    @Environment(\.fontScale) private var fontScale
    @Environment(\.chatFont) private var chatFont
    @Environment(\.chatLineHeight) private var chatLineHeight
    @Environment(\.transcriptHoverHost) private var hoverHost
    @Environment(\.transcriptBubbleWidth) private var bubbleWidth

    static let uncappedFallback: CGFloat = 560

    private var maxWidth: CGFloat { bubbleWidth?.cap ?? Self.uncappedFallback }

    @State private var hovered: FileChipHover?
    @State private var textFrame: CGRect = .zero
    @State private var hoverTask: Task<Void, Never>?
    @State private var published: TranscriptHoverCard?

    static let inset: CGFloat = 32

    static let corner: CGFloat = 12

    static let padding = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: Self.inset)

            CappedWidth(width: maxWidth) {
                bubble.padding(Self.padding)
            }
            .padding(.bottom, OutgoingBubbleShape.tailDrop)
            .background(.quaternary, in: OutgoingBubbleShape(cornerRadius: Self.corner))
        }
        .padding(.horizontal, TranscriptLayout.inset)
        .padding(.vertical, TranscriptLayout.inset)
        .onChange(of: hovered) { _, chip in
            hoverTask?.cancel()
            guard let chip else {
                withdraw()
                return
            }
            let wanted = card(for: chip.subject)
            hoverTask = Task {
                try? await Task.sleep(for: Motion.hoverCardDelay)
                guard !Task.isCancelled, textFrame != .zero else { return }
                publish(wanted, at: chip.frame.offsetBy(dx: textFrame.minX, dy: textFrame.minY))
            }
        }
        .onDisappear {
            hoverTask?.cancel()
            withdraw()
        }
    }

    @ViewBuilder
    private var bubble: some View {
        VStack(alignment: .leading, spacing: TranscriptLayout.block) {
            if !text.isEmpty {
                let font = Typo.body.resolvedNSFont(scale: fontScale, face: chatFont)
                    TranscriptTextView(
                    text: TranscriptLink.attributedString(
                        sent: text,
                        font: font,
                        color: .labelColor,
                        lineSpacing: TranscriptLayout.proseLeading(
                            Typo.body, scale: fontScale, face: chatFont, lineHeight: chatLineHeight
                        ),
                        chipGround: .userBubble
                    ),
                    linkColor: Palette.linkNSColor,
                    selectionColor: .selectedTextBackgroundColor,
                    alignsBubbleInk: true,
                    actions: linkActions.opening(
                        file: open, hovering: { hovered = $0 },
                        previewing: { PromptAttachment.sent(path: $0).url(in: home.worktree) }
                    )
                )
                .background { chipProbe }
            }

            if !reviewChips.isEmpty {
                ReviewTurnChips(chips: reviewChips, home: home)
            }

            if !attachments.isEmpty {
                ChipFlow(spacing: Metrics.spacingSmall, lineSpacing: Metrics.spacingSmall) {
                    ForEach(attachments, id: \.self) { path in
                        AttachmentChip(
                            attachment: .sent(path: path),
                            worktree: home.worktree,
                            onOpen: { open(path) },
                            onPreview: { frame in preview(path, frame) },
                            verifiesOnDisk: false
                        )
                    }
                }
            }
        }
    }

    private func open(_ path: String) {
        guard let id = home.workspaceID, let model = app.existingModel(for: id) else { return }
        FileReview.open(path: path, in: model)
    }

    @ViewBuilder
    private var chipProbe: some View {
        if hoverHost != nil, hovered != nil {
            Color.clear
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                    textFrame = $0
                }
        }
    }

    private func card(for subject: InlineChip) -> TranscriptHoverCard {
        switch subject {
        case .file(let path):
            let target = FileChipTarget.resolve(path, in: home.worktree)
            return .file(attachment: .sent(path: target.path), worktree: target.worktree)
        case .instructions(let block):
            return .instructions(title: block.title, body: block.body)
        }
    }

    private func preview(_ path: String, _ frame: CGRect?) {
        guard let frame else {
            withdraw()
            return
        }
        publish(card(for: .file(path: path)), at: frame)
    }

    private func publish(_ card: TranscriptHoverCard, at frame: CGRect) {
        published = card
        hoverHost?.request = TranscriptHoverRequest(card: card, frame: frame)
    }

    private func withdraw() {
        defer { published = nil }
        guard let published, hoverHost?.request?.card == published else { return }
        hoverHost?.request = nil
    }
}

extension TranscriptLinkActions {
    @MainActor
    func opening(
        file open: @escaping @MainActor @Sendable (String) -> Void,
        hovering hover: @escaping @MainActor @Sendable (FileChipHover?) -> Void,
        previewing preview: @escaping @MainActor @Sendable (String) -> URL?
    ) -> TranscriptLinkActions {
        var copy = self
        copy.openFile = open
        copy.hoverFile = hover
        copy.previewFile = preview
        if case let .workspace(id, pane) = identity {
            copy.identity = .workspaceOpeningFiles(id, pane: pane)
        }
        return copy
    }
}

struct CappedWidth: Layout {
    var width: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let subview = subviews.first else { return .zero }
        let limit = min(proposal.width ?? width, width)
        return subview.sizeThatFits(ProposedViewSize(width: limit, height: proposal.height))
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        subviews.first?.place(
            at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size)
        )
    }
}
