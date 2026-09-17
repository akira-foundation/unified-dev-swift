import SwiftUI

struct StreamingTailView: View {
    let transcript: TranscriptModel

    var body: some View {
        Group {
            if transcript.isRunning || transcript.isStreaming {
                StreamingRowView(transcript: transcript)
                    .padding(.bottom, TranscriptLayout.block)
            }
        }
    }
}
