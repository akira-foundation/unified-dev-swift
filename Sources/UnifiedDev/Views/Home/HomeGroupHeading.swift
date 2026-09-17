import SwiftUI

struct HomeGroupHeading: View {
    var title: String
    var isSecondary = false

    var body: some View {
        Text(title)
            .font(Typo.title)
            .foregroundStyle(isSecondary ? Palette.textSecondary : Palette.textPrimary)
            .padding(.top, Metrics.inset)
            .padding(.bottom, Metrics.spacingSmall)
            .accessibilityAddTraits(.isHeader)
    }
}
