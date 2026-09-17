import SwiftUI

struct WelcomePromptSubmission: View {
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.pane - Metrics.spacingSmall) {
            VStack(alignment: .leading, spacing: Metrics.spacing) {
                Text("Say what Unified Dev does next")
                    .font(Typo.displayHeading)
                    .foregroundStyle(Palette.textPrimary)

                Text(
                    "Prompt a coding agent to build what you want to see in Unified Dev, in the words "
                        + "you would say it to one. If we like your prompt we run it, and the "
                        + "result is merged."
                )
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: Metrics.spacing) {
                HStack(alignment: .top, spacing: Metrics.gutter) {
                    Text(
                        "A name gets you credited in the changelog, an address gets you told when "
                            + "it ships, and both are optional. Nothing from your projects or "
                            + "your sessions goes with it."
                    )
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    Button("Submit a prompt…") { onSubmit() }
                }

                Text(
                    "The form opens in the main window, and the Help menu has it under Submit a "
                        + "Prompt whenever you want it."
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
