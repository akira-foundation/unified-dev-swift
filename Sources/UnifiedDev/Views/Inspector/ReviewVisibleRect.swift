import SwiftUI
import Core

enum ReviewDocument {
    nonisolated static let space = "review-document"
}

extension EnvironmentValues {
    @Entry var reviewVisibleRect: CGRect?
}

extension View {
    func publishesReviewVisibleRect() -> some View {
        modifier(ReviewVisibleRectPublisher())
    }
}

private struct ReviewVisibleRectPublisher: ViewModifier {
    @State private var published: CGRect?

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGRect.self) { geometry in
                let visible = geometry.visibleRect
                let top = ReviewViewport.publishedTop(visibleTop: visible.minY, visibleHeight: visible.height)
                return CGRect(x: 0, y: top, width: 0, height: visible.height)
            } action: { _, rect in
                published = rect
            }
            .environment(\.reviewVisibleRect, published)
    }
}
