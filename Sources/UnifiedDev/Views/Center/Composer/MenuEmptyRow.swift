import SwiftUI

struct MenuEmptyRow: View {
    var text: String
    var inset: CGFloat = Metrics.spacing + Metrics.spacingSmall

    var body: some View {
        Text(text)
            .font(Typo.label)
            .foregroundStyle(Palette.textTertiary)
            .lineLimit(1)
            .frame(height: Metrics.rowHeight)
            .padding(.horizontal, inset)
            .padding(.vertical, Metrics.spacingSmall)
    }
}
