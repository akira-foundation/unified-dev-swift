import SwiftUI

struct ExpandableRowHeader<Content: View>: View {
    var isExpanded: Bool
    var onToggle: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        Button(action: onToggle) {
            content
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        .accessibilityHint(isExpanded ? "Collapses this row" : "Expands this row")
    }
}
