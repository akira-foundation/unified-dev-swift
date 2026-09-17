import SwiftUI

struct ProseRowView: View {
    var text: String
    var isStreaming = false

    var body: some View {
        VStack(alignment: .leading, spacing: TranscriptLayout.block) {
            MarkdownView(text, isStreaming: isStreaming)
                .font(Typo.body)
                .proseLeading()
                .textSelection(.enabled)
                .frame(maxWidth: TranscriptLayout.proseMeasure, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, TranscriptLayout.inset)
        .padding(.vertical, TranscriptLayout.block)
    }
}
