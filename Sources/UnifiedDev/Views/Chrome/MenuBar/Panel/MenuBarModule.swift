import SwiftUI
import Core

enum MenuBarModuleStyle {
    static let gap: CGFloat = 10
    static let corner: CGFloat = 22
    static let inset: CGFloat = 14
    static let chip: CGFloat = 30
}

struct MenuBarModule: ViewModifier {
    let title: String
    var inset: CGFloat = MenuBarModuleStyle.inset

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: MenuBarModuleStyle.corner, style: .continuous)
        content
            .padding(inset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if reduceTransparency {
                    shape.fill(Color(nsColor: .windowBackgroundColor))
                }
            }
            .glassEffect(reduceTransparency ? .identity : .regular, in: shape)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(title)
    }
}

extension View {
    func menuBarModule(_ title: String, inset: CGFloat = MenuBarModuleStyle.inset) -> some View {
        modifier(MenuBarModule(title: title, inset: inset))
    }

    @ViewBuilder
    func panelFocus(_ focus: FocusState<MenuBarPanelFocus?>.Binding?, _ target: MenuBarPanelFocus) -> some View {
        if let focus {
            focusable().focused(focus, equals: target)
        } else {
            self
        }
    }
}
