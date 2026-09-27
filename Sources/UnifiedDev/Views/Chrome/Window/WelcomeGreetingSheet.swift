import SwiftUI
import Core

struct WelcomeGreetingSheet: View {
    let action: () -> Void

    var body: some View {
        WelcomeSheet(
            title: "Welcome to Unified Dev",
            subtitle: "A worktree, an agent and a branch for every task you describe",
            actionTitle: OnboardingFlow.startTitle,
            action: action
        ) {
            VStack(alignment: .leading, spacing: Metrics.pane - Metrics.spacingSmall) {
                ForEach(WelcomeHighlight.all) { highlight in
                    WelcomeHighlightRow(highlight: highlight)
                }
            }
        }
    }
}
