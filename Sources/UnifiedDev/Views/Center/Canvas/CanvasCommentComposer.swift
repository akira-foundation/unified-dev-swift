import SwiftUI
import Core

struct CanvasCommentComposer: View {
    let action: String
    var initial = ""
    let commit: (String) -> Void
    let cancel: () -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    private var isBlank: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Add a comment", text: $text, axis: .vertical)
                .lineLimit(3...8)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: cancel)
                    .keyboardShortcut(.cancelAction)
                Button(action) { commit(text) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isBlank)
            }
            .controlSize(.small)
        }
        .onAppear {
            text = initial
            isFocused = true
        }
    }
}
