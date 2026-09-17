import SwiftUI

struct HoverRow<Content: View>: View {
    var isSelected: Bool
    var isFocused: Bool = false
    var content: Content

    @State private var isHovered = false

    init(isSelected: Bool, isFocused: Bool = false, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.isFocused = isFocused
        self.content = content()
    }

    var body: some View {
        content
            .rowBackground(isSelected: isSelected, isHovered: isHovered, isFocused: isFocused)
            .onHover { isHovered = $0 }
    }
}
