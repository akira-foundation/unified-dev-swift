import SwiftUI
import Core

struct BrowserViewportButton: View {
    @Binding var viewport: BrowserViewport
    @State private var showsControls = false

    var body: some View {
        BrowserToolbarButton(control: BrowserToolbar.viewport(viewport)) {
            showsControls.toggle()
        }
        .accessibilityValue(viewport.isEnabled ? "\(viewport.width) × \(viewport.height)" : "Full size")
        .popover(isPresented: $showsControls, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Responsive preview").font(Typo.labelEmphasis)
                BrowserViewportBar(viewport: $viewport)
                Divider()
                let fullSize = BrowserToolbar.fullSize(viewport)
                Button(fullSize.name, systemImage: fullSize.symbol) {
                    viewport.isEnabled = false
                    showsControls = false
                }
                .buttonStyle(.borderless)
                .disabled(!fullSize.isEnabled)
                .help(fullSize.help)
            }
            .controlSize(.small)
            .padding(20)
            .frame(width: 430)
        }
    }
}
