import SwiftUI
import Core

struct RevertMenuItems: View {
    let entry: RevertMenuEntry
    var action: () -> Void

    var body: some View {
        Button(entry.title, role: .destructive, action: action)
            .disabled(!entry.isEnabled)
        if let note = entry.note {
            Text(note)
        }
    }
}
