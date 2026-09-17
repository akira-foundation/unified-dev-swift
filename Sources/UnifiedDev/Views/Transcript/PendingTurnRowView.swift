import SwiftUI
import Core

struct PendingTurnRowView: View {
    var delivery: Delivery
    var home: TranscriptHome = .init()
    var holdSentence: String?
    var canRetry = false
    var onRetry: @MainActor () -> Void = {}
    var canSteer = false
    var onSteer: @MainActor () -> Void = {}
    var onEdit: @MainActor () -> Void
    var onDelete: @MainActor () -> Void
    @Environment(\.transcriptBubbleWidth) private var bubbleWidth
    @Environment(AppModel.self) private var app
    @Environment(\.markdownLinkActions) private var linkActions
    @Environment(\.fontScale) private var fontScale
    @Environment(\.chatFont) private var chatFont
    @Environment(\.chatLineHeight) private var chatLineHeight
    @Environment(\.transcriptHoverHost) private var hoverHost
    var pointerInside = false

    @State private var isHovered = false
    @State private var hovered: FileChipHover?
    @State private var textFrame: CGRect = .zero
    @State private var hoverTask: Task<Void, Never>?
    @State private var published: TranscriptHoverCard?

    private var isPointedAt: Bool { isHovered || pointerInside }

    private static let inset = UserTurnRowView.inset
    private static let corner = UserTurnRowView.corner
    private static let padding = UserTurnRowView.padding

    private static let dots = StrokeStyle(lineWidth: Metrics.outline, dash: [2, 3])

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: Self.inset)

            VStack(alignment: .trailing, spacing: TranscriptLayout.tight) {
                if delivery.deliveredSeq == nil { bubble }
                caption
            }
        }
        .padding(.horizontal, TranscriptLayout.inset)
        .padding(.vertical, TranscriptLayout.inset)
        .onHover { isHovered = $0 }
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

    private var displayText: String {
        guard let review = ReviewTurn.split(delivery.body) else {
            return attachmentTurn.body
        }
        let count = review.chips.count
        let suffix = "\(count) review comment\(count == 1 ? "" : "s") attached"
        return review.message.isEmpty ? suffix : "\(review.message)\n\(suffix)"
    }

    private var bubble: some View {
        CappedWidth(width: bubbleWidth?.cap ?? UserTurnRowView.uncappedFallback) {
            VStack(alignment: .leading, spacing: TranscriptLayout.block) {
                if !displayText.isEmpty {
                    let font = Typo.body.resolvedNSFont(scale: fontScale, face: chatFont)
                    TranscriptTextView(
                        text: TranscriptLink.attributedString(
                            sent: displayText,
                            font: font,
                            color: NSColor(Palette.textSecondary),
                            lineSpacing: TranscriptLayout.proseLeading(
                                Typo.body,
                                scale: fontScale,
                                face: chatFont,
                                lineHeight: chatLineHeight
                            ),
                            chipGround: .composer
                        ),
                        linkColor: NSColor(Palette.link),
                        selectionColor: .selectedTextBackgroundColor,
                        alignsBubbleInk: true,
                        actions: linkActions.opening(
                            file: open, hovering: { hovered = $0 },
                            previewing: { PromptAttachment.sent(path: $0).url(in: home.worktree) }
                        )
                    )
                    .background { chipProbe }
                }

                if !attachmentTurn.paths.isEmpty {
                    ChipFlow(spacing: Metrics.spacingSmall, lineSpacing: Metrics.spacingSmall) {
                        ForEach(attachmentTurn.paths, id: \.self) { path in
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
            .padding(Self.padding)
        }
        .padding(.bottom, OutgoingBubbleShape.tailDrop)
        .background(Palette.surfaceRaised, in: OutgoingBubbleShape(cornerRadius: Self.corner))
        .overlay {
            OutgoingBubbleShape(cornerRadius: Self.corner)
                .strokeBorder(Palette.textTertiary, style: Self.dots)
        }
    }

    private var attachmentTurn: (body: String, paths: [String]) {
        AttachmentTrailer.split(delivery.body)
    }

    private func open(_ path: String) {
        guard let id = home.workspaceID, let model = app.existingModel(for: id) else { return }
        FileReview.open(path: path, in: model)
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

    @ViewBuilder
    private var chipProbe: some View {
        if hoverHost != nil, hovered != nil {
            Color.clear
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                    textFrame = $0
                }
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

    @ViewBuilder
    private var caption: some View {
        HStack(spacing: Metrics.gutter) {
            if let sentence = holdSentence {
                Text(sentence)
                    .foregroundStyle(Palette.textTertiary)
            }

            if canRetry {
                Button(delivery.state == .uncertain ? "Send Again" : "Try Again", action: onRetry)
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.link)
                    .pointerStyle(.link)
                    .help(delivery.state == .uncertain
                        ? "The agent may already have received this message. Send another attempt only after checking."
                        : "Try to send this message again.")
            }

            moreMenu
        }
        .font(Typo.caption)
    }

    private var moreMenu: some View {
        Menu {
            if canSteer {
                Button("Steer", systemImage: "arrow.turn.up.right", action: onSteer)
                    .help("Stops the turn that is running and sends this message now.")
            }

            if PendingMessageEdit.canEdit(delivery) {
                Button("Edit", systemImage: "pencil", action: onEdit)
                    .help("Takes this message back into the composer to change it.")
            }

            Button("Delete", systemImage: "trash", action: onDelete)
                .help("Takes this message back out of the queue. It is not sent.")
        } label: {
            Label("More for this message", systemImage: "ellipsis.circle")
                .labelStyle(.iconOnly)
                .imageScale(.medium)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .foregroundStyle(isPointedAt ? Palette.link : Palette.textTertiary)
        .pointerStyle(.link)
        .help("Steer, edit or delete this queued message")
    }
}
