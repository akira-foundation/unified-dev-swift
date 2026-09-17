import AppKit
import SwiftUI

struct SettingsScrollPocket: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.isHidden = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let root = nsView.window?.contentView else { return }
        Self.hidePockets(in: root)
    }

    static func hidePockets(in view: NSView) {
        if "\(type(of: view))".contains("Pocket") { view.isHidden = true }
        for subview in view.subviews { hidePockets(in: subview) }
    }
}

extension View {
    func hidesScrollEdgeRule() -> some View {
        background(SettingsScrollPocket())
    }
}
