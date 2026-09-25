import SwiftUI
import Core

struct ComposerFastModeToggle: View {
    var controls: ComposerControls
    var codexSpeed: CodexSpeed?
    var codexSpeedFailed: Bool
    var height: CGFloat?
    var onChange: @MainActor (Bool) -> Void

    var body: some View {
        let availability = controls.fastModeAvailability(
            codexSpeed: codexSpeed, codexSpeedFailed: codexSpeedFailed
        )
        if availability != .unavailable {
            let isOn = controls.isFast(codexSpeed: codexSpeed)
            Button { onChange(!isOn) } label: {
                Image(systemName: isOn ? "bolt.fill" : "bolt")
                    .font(Typo.label)
                    .foregroundStyle(isOn ? Palette.warning : Palette.textSecondary)
                    .padding(.horizontal, Metrics.spacing + Metrics.spacingSmall)
                    .padding(.vertical, Metrics.spacingSmall)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(height: height ?? Metrics.barHeight)
            .clipShape(Capsule())
            .glassEffect(.regular, in: Capsule())
            .overlay { Capsule().strokeBorder(Palette.border, lineWidth: Metrics.outline) }
            .disabled(availability == .loading)
            .help(controls.fastModeHelp(availability: availability))
            .accessibilityLabel("Fast mode")
            .accessibilityAddTraits(.isToggle)
            .accessibilityValue(isOn ? "On" : "Off")
        }
    }
}
