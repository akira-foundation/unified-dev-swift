import SwiftUI

struct InspectorFilterField: View {
    @Binding var query: String
    var onEscape: @MainActor () -> Void
    var onReturn: @MainActor () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: InspectorLayout.gap) {
            Image(systemName: "magnifyingglass")
                .font(Typo.micro)
                .imageScale(.small)
                .foregroundStyle(Palette.textTertiary)
                .frame(width: InspectorLayout.glyphWidth, alignment: .leading)
                .accessibilityHidden(true)

            TextField("Filter files", text: $query)
                .textFieldStyle(.plain)
                .font(Typo.body)
                .focused($isFocused)
                .autocorrectionDisabled()
                .onSubmit(onReturn)
                .onExitCommand(perform: onEscape)
                .accessibilityLabel("Filter files")

            if !query.isEmpty {
                Button(action: clear) {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(.small)
                        .foregroundStyle(Palette.textTertiary)
                }
                .buttonStyle(.glass)
                .help("Clear the filter")
                .accessibilityLabel("Clear the filter")
            }
        }
        .padding(.horizontal, InspectorLayout.inset)
        .frame(height: InspectorLayout.barHeight)
    }

    private func clear() {
        query = ""
        isFocused = true
    }
}
