import SwiftUI
import Core

struct AgentQuestionStepper: View {
    var step: AgentQuestionStep
    var isLive: Bool
    var onBack: () -> Void
    var onNext: () -> Void

    var body: some View {
        HStack(spacing: TranscriptLayout.tight) {
            Button("Back", action: onBack)
                .disabled(step.isFirst)

            Button("Next", action: onNext)
                .disabled(step.isLast)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(isLive ? "Walk the questions" : "Read the questions")
    }
}

struct AgentQuestionStepCount: View {
    var step: AgentQuestionStep

    var body: some View {
        Text(step.label)
            .font(Typo.micro)
            .tracking(Typo.microTracking)
            .foregroundStyle(Palette.textTertiary)
            .monospacedDigit()
            .accessibilityLabel("Question \(step.label)")
    }
}
