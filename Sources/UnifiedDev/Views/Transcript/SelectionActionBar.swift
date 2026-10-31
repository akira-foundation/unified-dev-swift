import SwiftUI

struct SelectionActionBar: View {
    var onSideChat: (() -> Void)?
    var onReply: () -> Void

    var body: some View {
        HStack(spacing: 0) {
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
        .padding(.horizontal, Metrics.spacingWide)
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
    var onReply: (TranscriptSelection) -> Void

    static let lift: CGFloat = 24

    var body: some View {
        GeometryReader { proxy in
            if let selection = reader.current {
                SelectionActionBar(
                    onSideChat: onSideChat.map { action in { reader.clear(); action(selection) } },
                    onReply: { reader.clear(); onReply(selection) }
                )
                .position(position(for: selection.anchor, in: proxy.size))
                .transition(.opacity)
            }
        }
    }

    private func position(for anchor: CGPoint, in size: CGSize) -> CGPoint {
        let above = anchor.y - Self.lift
        let y = above < Metrics.barHeight ? anchor.y + Self.lift : above
        let x = min(max(anchor.x, 120), max(size.width - 120, 120))
        return CGPoint(x: x, y: y)
    }
}
