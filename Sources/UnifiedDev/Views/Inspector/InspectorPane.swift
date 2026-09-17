import SwiftUI

struct InspectorPane: View {
    let model: WorkspaceModel?
    @Environment(AppModel.self) private var app

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        if let model {
            InspectorView(model: model)
                .disabled(app.isArchiving(model.workspace.id))
                .id(model.workspace.id)
        } else {
            EmptyStateView(
                glyph: "sidebar.right",
                title: "No workspace selected",
                message: "Pick a workspace to see what its agent changed."
            )
        }
    }
}
