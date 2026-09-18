import SwiftUI
import Core

enum MenuBarModuleStyle {
    static let gap: CGFloat = 10
    static let corner: CGFloat = 18
    static let panelCorner: CGFloat = 26
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
                shape.fill(Color(nsColor: .controlBackgroundColor).opacity(reduceTransparency ? 1 : 0.55))
            }
            .overlay {
                shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(title)
    }
}

struct MenuBarPanelPlatter: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: MenuBarModuleStyle.panelCorner, style: .continuous)
        content
            .clipShape(shape)
            .background {
                if reduceTransparency {
                    shape.fill(Color(nsColor: .windowBackgroundColor))
                }
            }
            .glassEffect(reduceTransparency ? .identity : .regular, in: shape)
    }
}

struct MenuBarPanelFocusRing: ViewModifier {
    let isFocused: Bool

    @Environment(\.menuBarPanelShowsFocus) private var showsFocus

    func body(content: Content) -> some View {
        content
            .focusEffectDisabled()
            .overlay {
                if isFocused, showsFocus {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                        .padding(-3)
                }
            }
    }
}

extension EnvironmentValues {
    @Entry var menuBarPanelShowsFocus = false
}

extension View {
    func menuBarModule(_ title: String, inset: CGFloat = MenuBarModuleStyle.inset) -> some View {
        modifier(MenuBarModule(title: title, inset: inset))
    }

    func menuBarPanelPlatter() -> some View {
        modifier(MenuBarPanelPlatter())
    }

    @ViewBuilder
    func panelFocus(_ focus: FocusState<MenuBarPanelFocus?>.Binding?, _ target: MenuBarPanelFocus) -> some View {
        if let focus {
            focusable()
                .focused(focus, equals: target)
                .modifier(MenuBarPanelFocusRing(isFocused: focus.wrappedValue == target))
        } else {
            self
        }
    }
}
