import SwiftUI

struct ExpandableRow: ViewModifier {
    var isHovered: Bool

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .rowBackground(isSelected: false, isHovered: isHovered)
    }
}
