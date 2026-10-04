import SwiftUI
import Core

struct SidebarStatusHeadingRow: View {
    var group: SidebarStatusGroup
    var count: Int
    var isFolded: Bool
    var onToggleFold: (() -> Void)?

    @State private var isHovered = false
    @Environment(\.sidebarRowIndent) private var rowIndent

    var body: some View {
        HStack(spacing: Metrics.spacingSmall) {
            Text(group.title.uppercased())
                .font(Typo.micro)
                .tracking(Typo.microTracking)
                .foregroundStyle(group == .needsYou ? Palette.warning : Palette.textTertiary)

            Text(count.formatted(Figures.count))
                .font(Typo.micro)
                .monospacedDigit()
                .foregroundStyle(Palette.textTertiary)

            Spacer(minLength: Metrics.spacingSmall)

            if onToggleFold != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: SidebarMetrics.caretSize, weight: .medium))
                    .foregroundStyle(Palette.textTertiary)
                    .rotationEffect(.degrees(isFolded ? 0 : 90))
                    .opacity(isHovered || isFolded ? 1 : 0)
            }
        }
        .padding(.leading, rowIndent)
        .padding(.trailing, Metrics.spacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onHoverChange { isHovered = $0 }
        .onTapGesture { onToggleFold?() }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel(count == 1 ? "\(group.title), 1 workspace" : "\(group.title), \(count) workspaces")
        .accessibilityValue(onToggleFold == nil ? "" : isFolded ? "Collapsed" : "Expanded")
    }
}
