import SwiftUI
import Core

struct ModelNameField: View {
    var onChoose: (@MainActor (String) -> Void)?

    @State private var typed = ""
    @State private var refusal: String?

    private var catalog: ComposerModelCatalog { .shared }

    private var isEmpty: Bool {
        typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.inset) {
            HStack(spacing: Metrics.spacing) {
                TextField("opus-5-5", text: $typed)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                    .accessibilityLabel("Model id")

                Button("Add", action: add)
                    .disabled(isEmpty)
            }

            if let refusal {
                Text(refusal)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: typed) { _, _ in refusal = nil }
    }

    private func add() {
        guard !isEmpty else { return }
        let outcome = catalog.name(typed)
        refusal = outcome.refusal
        guard let id = outcome.id else { return }
        typed = ""
        onChoose?(id)
    }
}
