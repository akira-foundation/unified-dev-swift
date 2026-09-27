import SwiftUI
import Core

struct WelcomeAgentChoice: View {
    let candidates: [AgentKind]
    let agentDefault: WelcomeAgentDefault

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing) {
            HStack(spacing: Metrics.spacingWide) {
                Text("New sessions start on")
                    .font(Typo.bodyEmphasis)
                    .foregroundStyle(Palette.textPrimary)

                Spacer(minLength: Metrics.spacingWide)

                Picker("New sessions start on", selection: selection) {
                    ForEach(candidates, id: \.self) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }

            Text(agentDefault.failure ?? "Change it any time in Settings, Sessions.")
                .font(Typo.label)
                .foregroundStyle(agentDefault.failure == nil ? Palette.textSecondary : Palette.warning)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear { agentDefault.load() }
    }

    private var shown: AgentKind {
        OnboardingAgentChoice.selection(
            among: candidates, current: agentDefault.selected ?? AppDefaults.fallbackBackend
        ) ?? AppDefaults.fallbackBackend
    }

    private var selection: Binding<AgentKind> {
        Binding(
            get: { shown },
            set: { kind in MainActor.assumeIsolated { agentDefault.choose(kind) } }
        )
    }
}
