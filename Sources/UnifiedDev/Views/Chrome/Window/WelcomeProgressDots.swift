import SwiftUI
import Core

struct WelcomeProgressDots: View {
    let progress: OnboardingProgress
    let leadingInset: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Metrics.spacing) {
            ForEach(1...max(progress.count, 1), id: \.self) { position in
                Circle()
                    .fill(position == progress.position ? Palette.controlAccent : Palette.textTertiary.opacity(0.35))
                    .frame(width: Metrics.spacing, height: Metrics.spacing)
            }
        }
        .padding(.leading, leadingInset)
        .animation(reduceMotion ? nil : Motion.pane, value: progress.position)
        .accessibilityElement()
        .accessibilityLabel(progress.accessibilityLabel)
    }
}
