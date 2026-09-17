import SwiftUI
import Core

struct ViewedToggle: View {
    var model: WorkspaceModel
    var file: ChangedFile

    private var isViewed: Bool { model.isViewed(file) }
    private var action: ReviewedMarkAction { ReviewedMarkAction(isViewed: isViewed) }

    var body: some View {
        Toggle(isOn: Binding(get: { isViewed }, set: { mark($0) })) {
            Label("Viewed", systemImage: isViewed ? "checkmark.circle.fill" : "checkmark.circle")
        }
        .toggleStyle(.button)
        .inspectorBarControl()
        .help(action.help(for: file.filename))
        .accessibilityLabel(action.title)
    }

    private func mark(_ isViewed: Bool) {
        let model = model
        let file = file
        Task { await model.setViewed(isViewed, file: file) }
    }
}
