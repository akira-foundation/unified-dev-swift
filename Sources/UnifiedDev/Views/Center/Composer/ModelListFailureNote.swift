import SwiftUI
import Core

struct ModelListFailureNote: View {
    private var catalog: ComposerModelCatalog { .shared }

    var body: some View {
        let failures = ModelListFailure.reported(catalog.failures)
        if !failures.isEmpty {
            VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
                ForEach(failures) { failure in
                    Text(failure.sentence)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.warning)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .help(failure.sentence)
                }
                Button("Try Again") { catalog.load() }
                    .controlSize(.small)
                    .disabled(catalog.isLoading)
            }
        }
    }
}
