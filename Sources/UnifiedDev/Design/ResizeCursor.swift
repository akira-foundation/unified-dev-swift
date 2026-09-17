import SwiftUI
import AppKit

private struct ResizeCursor: ViewModifier {
    var cursor: NSCursor

    @State private var isPushed = false

    func body(content: Content) -> some View {
        content
            .onHoverChange { hovering in hold(hovering) }
            .onDisappear { hold(false) }
    }

    private func hold(_ wanted: Bool) {
        guard wanted != isPushed else { return }
        isPushed = wanted
        if wanted {
            cursor.push()
        } else {
            NSCursor.pop()
        }
    }
}

extension View {
    func resizeCursor(_ cursor: NSCursor) -> some View {
        modifier(ResizeCursor(cursor: cursor))
    }
}
