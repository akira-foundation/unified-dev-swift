import SwiftUI
import Core

struct WelcomeGreetingStep: View {
    let footer: WelcomeFooter
    let onSubmitPrompt: () -> Void

    static let title = "Welcome to Unified Dev"
    static let subtitle = "A worktree, an agent and a branch for every task you describe"
    static let promptTitle = "Say what Unified Dev does next"

    var body: some View {
        WelcomeStage(
            hero: .appIcon,
            title: Self.title,
            subtitle: Self.subtitle,
            link: WelcomeLink(title: Self.promptTitle, action: onSubmitPrompt),
            footer: footer
        ) {
            VStack(alignment: .leading, spacing: WelcomeMetrics.rowSpacing + Metrics.spacing) {
                ForEach(WelcomeHighlight.all) { highlight in
                    WelcomeHighlightRow(highlight: highlight)
                }
            }
        }
    }
}
