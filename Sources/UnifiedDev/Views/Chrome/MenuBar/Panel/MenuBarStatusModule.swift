import SwiftUI
import Core

struct MenuBarStatusModule: View {
    let content: MenuBarPanelContent
    var focus: FocusState<MenuBarPanelFocus?>.Binding?
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingWide) {
            HStack(alignment: .firstTextBaseline, spacing: Metrics.spacingWide) {
                Text(MenuBarPanelContent.statusTitle)
                    .font(Typo.title)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Metrics.spacingWide)
                badges
            }
            Text(content.sentence)
                .font(Typo.body)
                .fixedSize(horizontal: false, vertical: true)
            if content.needsSetup {
                Button(MenuBarPanelContent.setupAction, action: openSettings)
                    .linkButton()
                    .panelFocus(focus, .setup)
            }
        }
        .menuBarModule(MenuBarPanelContent.statusTitle)
    }

    private var badges: some View {
        HStack(spacing: Metrics.spacing) {
            ForEach(content.badges, id: \.self) { badge in
                Image(systemName: badge.symbolName)
                    .foregroundStyle(Palette.textSecondary)
                    .help(badge.label)
                    .accessibilityLabel(badge.label)
            }
        }
    }
}
