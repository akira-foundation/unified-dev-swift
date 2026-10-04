import SwiftUI
import Core

struct StartProjectCloneForm: View {
    @Bindable var model: StartProjectModel
    var onSubmit: () -> Void

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.gutter) {
            TextField("Paste an https or ssh address", text: $model.remote)
                .textFieldStyle(.roundedBorder)
                .font(Typo.body)
                .focused($isFieldFocused)
                .disabled(!model.isLocationLoaded)
                .onSubmit(onSubmit)

            StartProjectConsequenceBlock(said: model.cloneConsequence, home: model.home)
        }
        .task { isFieldFocused = true }
    }
}
