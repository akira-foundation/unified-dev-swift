import SwiftUI
import Core

struct MenuBarKeepAwakeChip: View {
    let hold: KeepAwake.Hold
    let now: Date
    @Binding var showsOptions: Bool
    var focus: FocusState<MenuBarPanelFocus?>.Binding?
    let openSettings: () -> Void

    @State private var keepAwake = KeepAwakeModel.shared
    @AppStorage(SleepPrevention.settingKey) private var whileAgentsRun = SleepPrevention.isOnByDefault
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let detail = KeepAwakeChip.detail(session: keepAwake.session, hold: hold, whileAgentsRun: whileAgentsRun, at: now)
        VStack(alignment: .leading, spacing: MenuBarModuleStyle.gap) {
            pill(detail: detail)
            if showsOptions {
                MenuBarKeepAwakeOptions(
                    session: keepAwake.session,
                    whileAgentsRun: whileAgentsRun,
                    now: now,
                    focus: focus,
                    choose: choose,
                    openSettings: openSettings
                )
                .menuBarModule(KeepAwakeChip.optionsLabel)
                .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func pill(detail: String) -> some View {
        HStack(spacing: Metrics.spacingWide) {
            Toggle(isOn: Binding(get: { KeepAwakeChip.isOn(session: keepAwake.session, at: now) }, set: { _ in tap() })) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(KeepAwake.title)
                        .font(Typo.labelEmphasis)
                    Text(detail)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                }
            }
            .toggleStyle(MenuBarChipToggleStyle(symbolName: KeepAwake.menuBarSymbol))
            .panelFocus(focus, .keepAwake)
            Button(action: reveal) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .rotationEffect(showsOptions ? .degrees(180) : .zero)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(KeepAwakeChip.optionsLabel)
            .accessibilityValue(showsOptions ? "Shown" : "Hidden")
            .panelFocus(focus, .keepAwakeOptions)
        }
        .padding(.vertical, 5)
        .padding(.leading, 5)
        .padding(.trailing, 10)
        .menuBarSurface(Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(KeepAwake.title)
    }

    private func tap() {
        keepAwake.perform(KeepAwakeChip.tap(session: keepAwake.session, at: Date()))
    }

    private func choose(_ choice: KeepAwakeChoice) {
        keepAwake.perform(KeepAwakeChip.choose(choice, whileAgentsRun: whileAgentsRun))
    }

    private func reveal() {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
            showsOptions.toggle()
        }
    }
}
