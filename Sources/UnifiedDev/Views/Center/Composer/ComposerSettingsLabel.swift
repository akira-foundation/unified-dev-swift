import SwiftUI
import Core

struct ComposerSettingsLabel: View {
    var text: String?
    var isActive: Bool
    var isOneOff: Bool
    var warns: Bool

    var body: some View {
        ComposerControlLabel(
            text: text,
            tint: Palette.textSecondary,
            isActive: isActive,
            showsMenuIndicator: true,
            showsDot: isOneOff
        ) {
            HStack(spacing: Metrics.spacingSmall) {
                Image(systemName: "slider.horizontal.3")
                if warns {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Palette.warning)
                        .accessibilityLabel(AgentAccountLine.unavailableTitle)
                }
            }
        }
    }
}
