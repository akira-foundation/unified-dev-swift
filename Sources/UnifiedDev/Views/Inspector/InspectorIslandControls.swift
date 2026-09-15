import SwiftUI
import Core

/// The row at the top of the inspector's island: which view, what it is measured from, and the
/// rest.
///
/// **These were toolbar items and could not stay there.** The window's bar is the centre column's
/// now, and the island runs from the top of the window, so an item in the bar over this pane would
/// be drawn on top of the island rather than above it. The same three controls, in the same order,
/// on the pane they act on.
struct InspectorIslandControls: View {
    @Bindable var model: WorkspaceModel

    var body: some View {
        HStack(spacing: Metrics.spacing) {
            InspectorViewPicker(model: model)

            Spacer(minLength: Metrics.spacingSmall)

            InspectorToolbar.GroupingButton(model: model)
            InspectorToolbar.ScopeMenu(model: model)
            InspectorToolbar.MoreMenu(model: model)
        }
        .buttonStyle(.plain)
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .labelStyle(.iconOnly)
        .foregroundStyle(Palette.textSecondary)
        .padding(.horizontal, InspectorLayout.inset)
        .frame(height: InspectorLayout.barHeight)
    }
}
