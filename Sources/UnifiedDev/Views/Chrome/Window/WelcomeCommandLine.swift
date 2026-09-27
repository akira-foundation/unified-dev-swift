import SwiftUI

struct WelcomeCommandLine: View {
    let command: String

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing) {
            WelcomeOfferRow(
                symbol: "terminal",
                headline: "Use Unified Dev from your terminal",
                detail: "Install the command, and a worktree is one line away."
            ) {
                EmptyView()
            }

            CommandLineOffer(command: command, fill: Palette.surfaceSunken)

            CommandLineWarning()
        }
    }
}
