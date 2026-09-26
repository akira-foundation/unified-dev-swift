import SwiftUI

struct WelcomeOffers: View {
    let registration: CommandLineRegistration
    let showsKeepAwake: Bool
    let onSubmitPrompt: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.inset + Metrics.spacingWide) {
            if showsKeepAwake {
                WelcomeKeepAwake()
            }

            if registration.isOffered, let command = registration.command {
                WelcomeCommandLine(command: command)
            }

            WelcomePromptSubmission(onSubmit: onSubmitPrompt)
        }
    }
}
