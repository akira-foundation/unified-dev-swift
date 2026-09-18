import SwiftUI
import Core

struct MenuBarChipsRow: View {
    let runningCount: Int
    let now: Date
    @Binding var showsOptions: Bool
    var focus: FocusState<MenuBarPanelFocus?>.Binding?
    let openApp: () -> Void
    let openSettings: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: MenuBarModuleStyle.gap) {
            MenuBarKeepAwakeChip(
                runningCount: runningCount,
                now: now,
                showsOptions: $showsOptions,
                focus: focus,
                openSettings: openSettings
            )
            Button(action: openApp) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: MenuBarModuleStyle.chip, height: MenuBarModuleStyle.chip)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(MenuBarPanelContent.openAppLabel)
            .accessibilityLabel(MenuBarPanelContent.openAppLabel)
            .panelFocus(focus, .openApp)
            .menuBarModule(MenuBarPanelContent.openAppLabel)
            .frame(width: MenuBarModuleStyle.chip + MenuBarModuleStyle.inset * 2)
        }
    }
}
