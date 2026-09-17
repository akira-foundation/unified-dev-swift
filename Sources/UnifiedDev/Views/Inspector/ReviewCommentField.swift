import SwiftUI

struct ReviewCommentField: View {
    @Binding var text: String
    var placeholder: String
    var onSubmit: @MainActor () -> Void
    var onCancel: @MainActor () -> Void

    @State private var caret = 0
    @State private var isFocused = false
    @State private var contentHeight = ComposerTextEditor.lineHeight

    private static let minimumLines: CGFloat = 1
    private static let maximumLines: CGFloat = 8

    var body: some View {
        ComposerEditor(
            text: $text,
            caret: $caret,
            isFocused: $isFocused,
            height: height,
            onContentHeightChange: { contentHeight = $0 },
            onKey: handle(key:),
            onAttach: { _, _ in false },
            placeholder: placeholder,
            accessibilityLabel: "Review comment"
        )
        .composerBox(isFocused: $isFocused)
        .task { isFocused = true }
    }

    private var height: CGFloat {
        let line = ComposerTextEditor.lineHeight
        return min(max(contentHeight, line * Self.minimumLines), line * Self.maximumLines)
    }

    private func handle(key: ComposerKey) -> Bool {
        switch key {
        case .returnKey, .commandReturn:
            onSubmit()
            return true
        case .escape:
            onCancel()
            return true
        case .up, .down, .tab:
            return false
        }
    }
}
