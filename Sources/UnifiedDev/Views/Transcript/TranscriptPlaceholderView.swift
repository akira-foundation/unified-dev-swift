import SwiftUI

struct TranscriptPlaceholderView: View {
    var isRunningSetup: Bool

    var emptyState: TranscriptEmptyState?

    var body: some View {
        if isRunningSetup {
            EmptyStateView(
                glyph: "gearshape.2",
                title: "Setting up the workspace",
                message: "The setup script is still running. Ask for something now and it goes as soon as that finishes."
            )
        } else if let emptyState {
            EmptyStateView(glyph: emptyState.glyph, title: emptyState.title, message: emptyState.message)
        } else {
            EmptyStateView(
                glyph: "text.alignleft",
                title: "Nothing here yet",
                message: "Ask for something below and the agent's work shows up here."
            )
        }
    }
}

struct TranscriptEmptyState: Equatable {
    var glyph: String
    var title: String
    var message: String
}
