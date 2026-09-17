import SwiftUI

struct TranscriptStreamingSignal: View {
    let transcript: TranscriptModel
    let report: @MainActor (Bool) -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .onChange(of: transcript.isStreaming, initial: true) { _, streaming in
                report(streaming)
            }
    }
}
