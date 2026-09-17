import SwiftUI

struct ReviewDiffBlock<Content: View>: View {
    var height: CGFloat
    var viewportHeight: CGFloat
    @ViewBuilder var content: () -> Content

    @State private var isNearViewport = false
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    var body: some View {
        Color.clear
            .frame(height: height)
            .overlay(alignment: .topLeading) {
                if isNearViewport || voiceOverEnabled { content() }
            }
            .onGeometryChange(for: Bool.self) { [viewportHeight] proxy in
                let frame = proxy.frame(in: .scrollView(axis: .vertical))
                return frame.maxY > -viewportHeight / 2 && frame.minY < viewportHeight * 1.5
            } action: {
                isNearViewport = $0
            }
    }
}
