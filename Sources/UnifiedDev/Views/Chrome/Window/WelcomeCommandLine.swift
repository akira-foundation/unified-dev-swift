import SwiftUI

struct WelcomeCommandLine: View {
    let command: String

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.pane - Metrics.spacingSmall) {
            VStack(alignment: .leading, spacing: Metrics.spacing) {
                Text("Use Unified Dev from your own terminal")
                    .font(Typo.displayHeading)
                    .foregroundStyle(Palette.textPrimary)

                CommandLineInstruction(isLead: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: Metrics.spacing) {
                CommandLineOffer(command: command, fill: Palette.surfaceSunken)

                CommandLineWarning()

                Text(
                    "Unified Dev works without this. Settings has the command again, under Command Line, "
                        + "whenever you want it."
                )
                .font(Typo.caption)
                .foregroundStyle(Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Metrics.pane)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
