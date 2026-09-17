import SwiftUI
import AppKit
import Core

struct BrowserShareButton: View {
    var control: BrowserToolbar.Control
    var shareable: BrowserToolbar.Shareable?
    var opticalOffsetY: CGFloat = 0

    @State private var anchor = SharePickerAnchor()

    var body: some View {
        BrowserToolbarButton(control: control, opticalOffsetY: opticalOffsetY) {
            anchor.present(shareable)
        }
            .background(SharePickerAnchorView(anchor: anchor))
    }
}

@MainActor
final class SharePickerAnchor {
    fileprivate weak var view: NSView?

    private var picker: NSSharingServicePicker?

    func present(_ shareable: BrowserToolbar.Shareable?) {
        guard let shareable, let view, view.window != nil else { return }

        let item = NSPreviewRepresentingActivityItem(
            item: shareable.url, title: shareable.name, image: nil, icon: nil
        )
        let picker = NSSharingServicePicker(items: [item])
        self.picker = picker
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }
}

private struct SharePickerAnchorView: NSViewRepresentable {
    let anchor: SharePickerAnchor

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        anchor.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        anchor.view = nsView
    }
}
