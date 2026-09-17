import SwiftUI

struct TranscriptRowFrame: ViewModifier {
    @Environment(\.fontScale) private var fontScale

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, TranscriptLayout.inset)
            .frame(height: TranscriptLayout.rowHeight * fontScale)
    }
}

extension View {
    func transcriptRowFrame() -> some View {
        modifier(TranscriptRowFrame())
    }
}
