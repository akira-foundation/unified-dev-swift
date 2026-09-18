import SwiftUI
import Core

struct MenuBarKeepAwakeOptions: View {
    let session: KeepAwakeSession?
    let whileAgentsRun: Bool
    let now: Date
    var focus: FocusState<MenuBarPanelFocus?>.Binding?
    let choose: (KeepAwakeChoice) -> Void
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
            ForEach(KeepAwakeChoice.allCases) { choice in
                let isChosen = KeepAwakeChip.isChosen(choice, session: session, whileAgentsRun: whileAgentsRun, at: now)
                Button {
                    choose(choice)
                } label: {
                    HStack(spacing: Metrics.spacingWide) {
                        Image(systemName: "checkmark")
                            .opacity(isChosen ? 1 : 0)
                            .accessibilityHidden(true)
                        Text(choice.title)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isChosen ? .isSelected : [])
                .panelFocus(focus, .keepAwakeChoice(choice))
            }
            Divider()
            Button(KeepAwakeChip.settingsTitle, action: openSettings)
                .linkButton()
                .panelFocus(focus, .keepAwakeSettings)
        }
        .font(Typo.label)
    }
}

struct MenuBarChipToggleStyle: ToggleStyle {
    let symbolName: String

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: Metrics.spacingWide) {
                Image(systemName: symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(configuration.isOn ? Palette.onAccentFill : Palette.textPrimary)
                    .frame(width: MenuBarModuleStyle.chip, height: MenuBarModuleStyle.chip)
                    .background(Circle().fill(configuration.isOn ? Palette.accentFill : Palette.textPrimary.opacity(0.12)))
                configuration.label
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}
