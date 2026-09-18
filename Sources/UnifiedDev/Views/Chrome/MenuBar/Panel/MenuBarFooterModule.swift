import SwiftUI
import Core

struct MenuBarFooterModule: View {
    var focus: FocusState<MenuBarPanelFocus?>.Binding?
    let openSettings: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(spacing: Metrics.spacingSmall) {
            row(MenuBarPanelContent.settingsTitle, command: .openSettings, target: .settings, action: openSettings)
            Divider()
            row(MenuBarPanelContent.quitTitle, command: .quit, target: .quit, action: quit)
        }
        .menuBarModule(MenuBarPanelContent.footerTitle, inset: Metrics.inset)
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .panelFocus(focus, target)
    }
}
