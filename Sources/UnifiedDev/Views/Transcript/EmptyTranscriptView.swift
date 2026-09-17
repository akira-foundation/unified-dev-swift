import SwiftUI

struct EmptyTranscriptView: View {
    var body: some View {
        EmptyStateView(
            glyph: "text.alignleft",
            title: "No session",
            message: "Pick a workspace, or start a new one, and the agent's work shows up here."
        )
    }
}
