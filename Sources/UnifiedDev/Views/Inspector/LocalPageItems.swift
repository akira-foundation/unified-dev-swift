import SwiftUI
import Core

struct LocalPageItems: View {
    var path: String
    var open: @MainActor () -> Void
    var split: @MainActor (SplitAxis) -> Void

    var body: some View {
        if LocalPage.canOpen(file: path) {
            Button("Open in Browser Tab", action: open)
            Button("Open in Split Right") { split(.horizontal) }
            Button("Open in Split Down") { split(.vertical) }
        }
    }
}
