import SwiftUI

struct ReplyQuoteText: View {
    var summary: String

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.spacing) {
            Capsule()
                .fill(Palette.textTertiary)
                .frame(width: Self.barWidth)

            Text(summary)
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private static let barWidth: CGFloat = 2
}
