import SwiftUI
import Core

struct WelcomeProgressDots: View {
    let progress: OnboardingProgress

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let diameter: CGFloat = 7

    var body: some View {
        HStack(spacing: Metrics.spacing) {
            ForEach(1...max(progress.count, 1), id: \.self) { position in
                Circle()
                    .fill(position == progress.position ? Palette.controlAccent : Palette.textTertiary)
                    .frame(width: Self.diameter, height: Self.diameter)
            }
        }
        .animation(reduceMotion ? nil : Motion.pane, value: progress.position)
        .accessibilityElement()
        .accessibilityLabel(progress.accessibilityLabel)
        .accessibilityIdentifier("welcome-progress")
    }
}
