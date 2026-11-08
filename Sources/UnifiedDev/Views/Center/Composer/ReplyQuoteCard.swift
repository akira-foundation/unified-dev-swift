import SwiftUI
import Core

struct ReplyQuoteCard: View {
    var quote: ReplyQuote
    var onRemove: @MainActor () -> Void
    var onOpen: @MainActor () -> Void

    @State private var isHovered = false

    private static let width: CGFloat = 220

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
            ReplyQuoteText(summary: quote.summary)

            Text("Reply")
                .font(Typo.label)
                .foregroundStyle(Palette.textTertiary)
        }
        .padding(Metrics.spacing)
        .frame(width: Self.width, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                .fill(isHovered ? Palette.hover : Palette.surfaceRaised)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                .strokeBorder(Palette.border, lineWidth: Metrics.outline)
        }
        .overlay(alignment: .topTrailing) {
            if isHovered {
                ChipRemoveButton(diameter: AttachmentChip.slot, label: "Remove the quote", action: onRemove)
                    .padding(Metrics.spacingSmall)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: Metrics.cornerSmall))
        .onTapGesture(perform: onOpen)
        .onHover { isHovered = $0 }
        .help(quote.summary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reply to a quote")
        .accessibilityValue(quote.summary)
        .accessibilityAction(named: "Remove", onRemove)
        .accessibilityAction(named: "Show the message", onOpen)
    }
}
