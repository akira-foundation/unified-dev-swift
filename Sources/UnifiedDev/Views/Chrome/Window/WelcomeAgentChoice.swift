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

            Text("Change it any time in Settings, Sessions.")
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)
        }
        .onAppear { agentDefault.load() }
    }

    private var selection: Binding<AgentKind> {
        Binding(
            get: { agentDefault.selected ?? AppDefaults.fallbackBackend },
            set: { kind in MainActor.assumeIsolated { agentDefault.choose(kind) } }
        )
    }
}
