import SwiftUI
import Core

struct WelcomeOffers: View {
    let registration: CommandLineRegistration
    let onSubmitPrompt: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.inset + Metrics.spacingWide) {
            if Machine.isPortable {
                WelcomeKeepAwake()
            }

            if registration.isOffered, let command = registration.command {
                WelcomeCommandLine(command: command)
            }

            WelcomePromptSubmission(onSubmit: onSubmitPrompt)
        }
    }
}
