import SwiftUI
import Core

struct MenuBarFooterModule: View {
    var focus: FocusState<MenuBarPanelFocus?>.Binding?
    let openSettings: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            row(MenuBarPanelContent.settingsTitle, command: .openSettings, target: .settings, action: openSettings)
            row(MenuBarPanelContent.quitTitle, command: .quit, target: .quit, action: quit)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(MenuBarPanelContent.footerTitle)
    }

    private func row(
        _ title: String,
        command: MenuBarPanelKey.Command,
        target: MenuBarPanelFocus,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Metrics.spacingWide) {
                Text(title)
                Spacer(minLength: Metrics.spacingWide)
                if let key = MenuBarPanelKey.shortcut(for: command) {
                    Text(key.display)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .font(Typo.label)
            .padding(.horizontal, Metrics.inset)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuBarFooterRowStyle())
        .panelFocus(focus, target)
    }
}

private struct MenuBarFooterRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        MenuBarFooterRow(configuration: configuration)
    }
}

private struct MenuBarFooterRow: View {
    let configuration: ButtonStyle.Configuration

    @State private var isHovered = false

    var body: some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.14 : (isHovered ? 0.08 : 0)))
            }
            .onHover { isHovered = $0 }
    }
}
