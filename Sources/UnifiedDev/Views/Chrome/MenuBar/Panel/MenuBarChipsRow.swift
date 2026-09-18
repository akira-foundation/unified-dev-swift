import SwiftUI
import Core

struct MenuBarChipsRow: View {
    let hold: KeepAwake.Hold
    let now: Date
    @Binding var showsOptions: Bool
    var focus: FocusState<MenuBarPanelFocus?>.Binding?
    let openApp: () -> Void
    let openSettings: () -> Void

    var body: some View {
        MenuBarKeepAwakeChip(
            hold: hold,
            now: now,
            showsOptions: $showsOptions,
            focus: focus,
            openSettings: openSettings
        ) {
            Button(action: openApp) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: MenuBarModuleStyle.round, height: MenuBarModuleStyle.round)
                    .menuBarSurface(Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(MenuBarPanelContent.openAppLabel)
            .accessibilityLabel(MenuBarPanelContent.openAppLabel)
            .panelFocus(focus, .openApp)
        }
    }
}
