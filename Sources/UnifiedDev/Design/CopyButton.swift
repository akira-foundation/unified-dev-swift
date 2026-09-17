import SwiftUI

struct CopyButton: View {
    var text: String
    var title: String = "Copy"
    var isVisible: Bool = true
    var size: CGFloat?

    @State private var copied = false
    @State private var reset: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: copy) {
            ZStack {
                Image(systemName: "doc.on.doc")
                    .opacity(copied ? 0 : 1)

                Image(systemName: "checkmark")
                    .foregroundStyle(Palette.positive)
                    .opacity(copied ? 1 : 0)
            }
                .font(Typo.caption)
                .imageScale(.medium)
                .frame(width: 16, height: 16)
                .foregroundStyle(isVisible || copied ? Palette.textTertiary : Color.clear)
                .frame(width: size, height: size)
                .contentShape(Rectangle())
                .animation(reduceMotion ? nil : Motion.hover, value: copied)
        }
        .buttonStyle(.plain)
        .help(copied ? "Copied" : title)
        .accessibilityLabel(copied ? "Copied" : title)
        .onDisappear { reset?.cancel() }
    }

    private func copy() {
        Clipboard.copy(text)
        copied = true
        reset?.cancel()
        reset = Task {
            try? await Task.sleep(for: Clipboard.flashDuration)
            guard !Task.isCancelled else { return }
            copied = false
        }
    }
}
