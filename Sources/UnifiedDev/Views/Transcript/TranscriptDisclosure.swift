import SwiftUI

struct TranscriptDisclosure: View {
    var isExpanded: Bool
    var isVisible: Bool

    var body: some View {
        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
            .font(Typo.label)
            .imageScale(.small)
            .foregroundStyle(Palette.textTertiary)
            .frame(width: TranscriptLayout.disclosureWidth)
            .opacity(isVisible || isExpanded ? 1 : 0)
            .accessibilityHidden(true)
    }
}
