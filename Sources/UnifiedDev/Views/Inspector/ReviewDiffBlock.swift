import SwiftUI
import Core

struct ReviewDiffBlock<Content: View>: View {
    var height: CGFloat
    @ViewBuilder var content: () -> Content

    @State private var frame: CGRect?
    @Environment(\.reviewVisibleRect) private var visibleRect
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    var body: some View {
        Color.clear
            .frame(height: height)
            .overlay(alignment: .topLeading) {
                if isNearViewport || voiceOverEnabled { content() }
            }
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named(ReviewDocument.space))
            } action: {
                frame = $0
            }
    }

    private var isNearViewport: Bool {
        guard let frame, let visibleRect else { return false }
        return ReviewViewport.isNear(top: frame.minY, bottom: frame.maxY,
                                     visibleTop: visibleRect.minY, visibleHeight: visibleRect.height)
    }
}
