import SwiftUI
import Core

struct SelectionActionBar: View {
    var onSideChat: (() -> Void)?
    var onReply: () -> Void

    var body: some View {
        HStack(spacing: Metrics.spacingWide * 1.5) {
            if let onSideChat {
                Button("Start a side chat", action: onSideChat)
                Divider().frame(height: Metrics.barHeight / 2)
            }
            Button("Reply", action: onReply)
        }
        .buttonStyle(.borderless)
        .font(Typo.label)
        .foregroundStyle(Palette.textPrimary)
        .controlSize(.regular)
        .padding(.horizontal, Metrics.spacingWide * 2)
        .frame(height: Metrics.barHeight)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.border))
        .shadow(radius: 6, y: 2)
        .focusable(false)
        .fixedSize()
    }
}

struct SelectionActionOverlay: View {
    let reader: TranscriptSelectionReader
    var onSideChat: ((TranscriptSelection) -> Void)?
    var agent: String
    var onReply: (TranscriptSelection, String) -> Void

    @State private var replyHeight: CGFloat = 110

    static let lift: CGFloat = 24

    var body: some View {
        GeometryReader { proxy in
            if let selection = reader.current {
                SelectionActionBar(
                    onSideChat: onSideChat.map { action in { reader.clear(); action(selection) } },
                    onReply: { reader.beginReply(to: selection) }
                )
                .position(position(for: selection.anchor, in: proxy.size))
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: {
                    reader.barFrame = $0
                }
                .onDisappear { reader.barFrame = .null }
                .transition(.opacity)
            }
            if let replying = reader.replying, let summary = ReplyQuote.summary(of: replying.text) {
                SelectionReplyCard(
                    summary: summary,
                    agent: agent,
                    onCommit: { typed in
                        reader.endReply()
                        onReply(replying, typed)
                    },
                    onCancel: reader.endReply
                )
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: {
                    reader.replyFrame = $0
                    replyHeight = $0.height
                }
                .position(replyPosition(for: replying.anchor, in: proxy.size))
                .onDisappear { reader.replyFrame = .null }
                .transition(.opacity)
            }
        }
        .coordinateSpace(.named(Self.space))
    }

    private nonisolated static let space = "selectionOverlay"

    private func position(for anchor: CGPoint, in size: CGSize) -> CGPoint {
        let above = anchor.y - Self.lift
        let y = above < Metrics.barHeight ? anchor.y + Self.lift : above
        let x = min(max(anchor.x, 120), max(size.width - 120, 120))
        return CGPoint(x: x, y: y)
    }

    private func replyPosition(for anchor: CGPoint, in size: CGSize) -> CGPoint {
        let half = SelectionReplyCard.width / 2 + Metrics.spacingWide
        let above = anchor.y - Self.lift - replyHeight / 2
        let y = above - replyHeight / 2 < Metrics.spacingWide ? anchor.y + Self.lift + replyHeight / 2 : above
        return CGPoint(x: min(max(anchor.x, half), max(size.width - half, half)), y: y)
    }
}
