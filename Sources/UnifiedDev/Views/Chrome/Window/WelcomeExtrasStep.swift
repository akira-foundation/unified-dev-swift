import SwiftUI
import Core

struct WelcomeExtrasStep: View {
    let registration: CommandLineRegistration
    let showsKeepAwake: Bool
    @Binding var showsCommand: Bool
    let footer: WelcomeFooter

    static let title = "Two things you may want on"
    static let subtitle = "Both are optional, and both live in Settings if you would rather decide later."

    var body: some View {
        WelcomeStage(
            hero: .symbol("switch.2", Palette.controlAccent),
            title: Self.title,
            subtitle: Self.subtitle,
            footer: footer
        ) {
            VStack(alignment: .leading, spacing: WelcomeMetrics.rowSpacing) {
                if showsKeepAwake {
                    WelcomeKeepAwakeRow()
                }

                if registration.isOffered, let command = registration.command {
                    WelcomeToggleRow(
                        symbol: "terminal",
                        headline: "Use Unified Dev from your terminal",
                        detail: "Register the bridge once, and a worktree is one line away.",
                        isOn: $showsCommand
                    )

                    if showsCommand {
                        VStack(alignment: .leading, spacing: Metrics.spacing) {
                            CommandLineOffer(command: command, fill: Palette.surfaceSunken)
                            CommandLineWarning()
                        }
                        .accessibilityIdentifier("welcome-bridge-command")
                    }
                }
            }
        }
        .accessibilityIdentifier("welcome-extras")
    }
}
