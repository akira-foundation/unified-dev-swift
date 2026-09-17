import SwiftUI

struct StreamingRowView: View {
    let transcript: TranscriptModel

    private var hasVisibleStream: Bool {
        !transcript.streamingThinking.isEmpty || !transcript.streamingText.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !transcript.streamingThinking.isEmpty {
                StreamingThinkingView(
                    text: transcript.streamingThinking,
                    tokens: transcript.thinkingTokens
                )
                .transaction { $0.animation = nil }
                .messageArrival(transcript.messageArrivals.stream(.thinking))
            }

            if !transcript.streamingText.isEmpty {
                ProseRowView(text: transcript.streamingText, isStreaming: true)
                    .transaction { $0.animation = nil }
                    .messageArrival(transcript.messageArrivals.stream(.assistantText))
            }

            if let run = transcript.retryRun {
                RetryRowView(run: run)
                    .transaction { $0.animation = nil }
            } else if let tool = transcript.streamingToolName {
                StreamingStatusView(glyph: "gearshape", text: "Running \(tool)")
                    .transaction { $0.animation = nil }
            } else if transcript.isRunning, !hasVisibleStream {
                StreamingStatusView(glyph: nil, text: transcript.statusLabel ?? "Working")
                    .transaction { $0.animation = nil }
            }
        }
    }
}
