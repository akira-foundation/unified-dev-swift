import SwiftUI
import Core

struct TranscriptView: View {
    private let transcript: TranscriptModel?
    private let isRunningSetup: Bool
    private let emptyState: TranscriptEmptyState?

    private let onScrolledUpChange: (@MainActor @Sendable (Bool) -> Void)?

    private let memory: TranscriptPaneMemory?

    init(
        transcript: TranscriptModel,
        isRunningSetup: Bool = false,
        emptyState: TranscriptEmptyState? = nil,
        memory: TranscriptPaneMemory? = nil,
        onScrolledUpChange: (@MainActor @Sendable (Bool) -> Void)? = nil
    ) {
        self.transcript = transcript
        self.isRunningSetup = isRunningSetup
        self.emptyState = emptyState
        self.memory = memory
        self.onScrolledUpChange = onScrolledUpChange
    }

    init(
        transcript: TranscriptModel?,
        isRunningSetup: Bool = false,
        emptyState: TranscriptEmptyState? = nil,
        memory: TranscriptPaneMemory? = nil,
        onScrolledUpChange: (@MainActor @Sendable (Bool) -> Void)? = nil
    ) {
        self.transcript = transcript
        self.isRunningSetup = isRunningSetup
        self.emptyState = emptyState
        self.memory = memory
        self.onScrolledUpChange = onScrolledUpChange
    }

    var body: some View {
        Group {
            if let transcript {
                TranscriptListView(
                    transcript: transcript,
                    isRunningSetup: isRunningSetup,
                    emptyState: emptyState,
                    memory: memory,
                    onScrolledUpChange: onScrolledUpChange
                )
            } else {
                EmptyTranscriptView()
            }
        }
    }
}
