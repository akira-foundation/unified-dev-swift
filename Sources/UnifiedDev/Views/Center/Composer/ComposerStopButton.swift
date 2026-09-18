import SwiftUI

struct ComposerStopButton: View {
    var onStop: @MainActor () -> Void

    var body: some View {
        Button(action: onStop) {
            Label("Stop the agent", systemImage: "stop.fill")
                .labelStyle(.iconOnly)
                .font(Typo.labelEmphasis)
                .padding(Metrics.spacingSmall)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .tint(Palette.stop)
        .help("Stop the agent (⌘.)")
    }
}
