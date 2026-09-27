import SwiftUI

struct WelcomePromptSubmission: View {
    let onSubmit: () -> Void

    var body: some View {
        WelcomeOfferRow(
            symbol: "bubble.left.and.text.bubble.right",
            headline: "Say what Unified Dev does next",
            detail: "Prompt an agent for what you want to see. The form opens in the main window."
        ) {
            Button("Submit…") { onSubmit() }
        }
    }
}
