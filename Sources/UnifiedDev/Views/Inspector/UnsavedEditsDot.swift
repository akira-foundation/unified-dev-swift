import SwiftUI

struct UnsavedEditsDot: View {
    var session: FileEditSession
    var path: String

    var body: some View {
        if session.isDirty(path) {
            Circle()
                .fill(Palette.accent)
                .frame(width: Metrics.dot, height: Metrics.dot)
                .help("Unsaved changes")
                .accessibilityLabel("Unsaved changes")
        }
    }
}
