import SwiftUI

struct SelectionReplyCard: View {
    var summary: String
    var agent: String
    var onCommit: (String) -> Void

    @State private var typed = ""
    @FocusState private var isFocused: Bool

    static let width: CGFloat = 380
    private static let inset: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: Self.inset) {
            ReplyQuoteText(summary: summary)

            HStack(alignment: .bottom, spacing: Metrics.spacingWide) {
                TextField("", text: $typed, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(Typo.body)
                    .lineLimit(1...5)
                    .focused($isFocused)
                    .onSubmit(commit)
                    .accessibilityLabel("Reply to \(agent)")
                    .background(alignment: .topLeading) {
                        if typed.isEmpty {
                            Text("Reply to \(agent)")
                                .font(Typo.body)
                                .foregroundStyle(Palette.textPlaceholder)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }

                Button(action: commit) {
                    Image(systemName: "plus.bubble")
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                }
                .buttonStyle(.borderless)
                .help("Add to the composer")
                .accessibilityLabel("Add to the composer")
            }
        }
        .padding(Self.inset)
        .frame(width: Self.width, alignment: .leading)
        .background(Palette.floatingCard, in: RoundedRectangle(cornerRadius: Metrics.cornerLarge))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cornerLarge)
                .strokeBorder(Palette.border, lineWidth: Metrics.outline)
        }
        .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { isFocused = true }
    }

    private func commit() {
        onCommit(typed)
    }
}
