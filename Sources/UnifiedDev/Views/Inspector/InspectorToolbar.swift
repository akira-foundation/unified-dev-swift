import SwiftUI
import Core

/// The inspector's tab row and actions for reviewing and arranging its files.
///
/// Tabs connect the selected scope to the pane below. When the inspector becomes too narrow for
/// the labels, `ViewThatFits` falls back to a pop-up button.
///
/// Only the controls that mean something for the pane below are drawn. A row of four trailing
/// buttons pushed the picker into its narrow form at the DEFAULT inspector width, and two of them
/// did nothing at all on the checks tab.
enum InspectorToolbar {

    /// Whether the changed files are grouped by folder.
    ///
    /// No plate of its own: the toolbar section around it is the visible container, and the state
    /// is said by the symbol, filled while the grouping is on.
    struct GroupingButton: View {
        @Bindable var model: WorkspaceModel

        @AppStorage(ChangedFilePresentation.storageKey)
        private var isTree = ChangedFilePresentation.defaultsToTree

        var body: some View {
            Button { isTree.toggle() } label: {
                Image(systemName: isTree ? "folder.fill" : "folder")
            }
            .disabled(model.inspectorTab != .changes || model.changedFiles.isEmpty)
            .accessibilityLabel("Group changes by folder")
            .accessibilityAddTraits(isTree ? .isSelected : [])
            .help(
                isTree
                    ? "Show the changed files as a flat list"
                    : "Group the changed files by folder"
            )
        }
    }

    /// What the list is measured from. Which scope is in force is said by the band under the
    /// list rather than by a shade of this glyph, for the width reason `DiffScopeBand` spells out.
    struct ScopeMenu: View {
        @Bindable var model: WorkspaceModel

        var body: some View {
            Menu {
                DiffScopeMenuItems(model: model)
            } label: {
                Label(
                    "What the changes are measured from",
                    systemImage: "line.3.horizontal.decrease"
                )
            }
            .disabled(model.inspectorTab != .changes)
            .help("What the changes are measured from")
        }
    }

    /// Merge, and the menu that says which merge, in the bar.
    ///
    /// The same control the band at the foot of the pane carries, and the same path: it chooses
    /// the method through the model and sends the request through `requestMerge`, which composes a
    /// turn for the agent rather than running `gh` here. Two controls for one action, which is
    /// what the owner asked for with Push as well.
    ///
    /// Only while GitHub would take a merge. A split button that cannot merge is a control whose
    /// disabled state somebody has to explain, and the band already explains it.
    struct MergeButton: View {
        @Bindable var model: WorkspaceModel

        @State private var isWorking = false

        var body: some View {
            Menu {
                Picker("Merge method", selection: binding) {
                    ForEach(MergeMethodChoice.offered, id: \.self) { offered in
                        Text(offered.label).tag(offered)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } label: {
                // The words, not a glyph. `arrow.triangle.merge` at toolbar size is three strokes
                // nobody reads as merging, and this is the one irreversible action in the window:
                // it says what it does. The band at the foot of the pane says it the same way.
                Text(model.mergeMethod.buttonLabel)
            } primaryAction: {
                merge()
            }
            .menuStyle(.button)
            .buttonBorderShape(.capsule)
            .disabled(isWorking)
            .help(model.mergeMethod.buttonLabel)
            .id(model.mergeMethod)
        }

        private var binding: Binding<GitHub.MergeMethod> {
            Binding(
                get: { model.mergeMethod },
                set: { method in Task { await model.chooseMergeMethod(method) } }
            )
        }

        private func merge() {
            guard let pullRequest = model.pullRequest else { return }
            isWorking = true
            Task {
                defer { isWorking = false }
                _ = await model.requestMerge(pullRequest, method: model.mergeMethod)
            }
        }
    }

    /// Hands the outstanding work to the agent, which is the same thing the band at the foot of
    /// the pane does with its own button. Two controls for one action, deliberately: see the item
    /// in `InspectorView` for the argument.
    struct PushButton: View {
        @Bindable var model: WorkspaceModel

        @State private var isWorking = false

        var body: some View {
            Button {
                isWorking = true
                Task {
                    defer { isWorking = false }
                    _ = await model.requestPush()
                }
            } label: {
                Label("Push", systemImage: "arrow.up.circle")
            }
            .disabled(isWorking)
            .help("Hand the outstanding work to the agent to commit and push")
        }
    }

    /// The rest, as `WorktreeMenuItems`, which is a view of its own so the menu can be
    /// photographed. There is no Refresh on it: the list keeps itself current.
    struct MoreMenu: View {
        @Bindable var model: WorkspaceModel

        var body: some View {
            Menu {
                WorktreeMenuItems(workspace: model.workspace, pullRequest: model.pullRequest)
            } label: {
                Label("More for this worktree", systemImage: "ellipsis")
            }
            .help("More for this worktree")
        }
    }

}

/// A tab's name, with the count the Changes tab carries.
@MainActor
enum InspectorTabTitle {
    static func of(_ tab: InspectorTab, model: WorkspaceModel) -> String {
        guard tab == .changes, !model.changedFiles.isEmpty else { return tab.rawValue }
        return "\(tab.rawValue) (\(model.changedFiles.count))"
    }
}

/// The inspector's view switch, on its own in the toolbar.
///
/// A section of its own rather than a member of the actions group beside it: a segmented control
/// and a run of symbols sharing one plate read as one control with a text end and a symbol end,
/// which is the illusion the toolbar guidance warns about.
struct InspectorViewPicker: View {
    @Bindable var model: WorkspaceModel

    var body: some View {
        // A glyph, not the words. It used to print "Changes (8)" in a bar whose every other item
        // is a single symbol, which made the section read as one control with a text end; the tab
        // is said by its glyph and the count belongs to the list under it.
        Menu {
            Picker("Inspector view", selection: $model.inspectorTab) {
                ForEach(model.availableInspectorTabs, id: \.self) { tab in
                    Label(InspectorTabTitle.of(tab, model: model), systemImage: tab.symbol).tag(tab)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            Label(title, systemImage: model.inspectorTab.symbol)
        }
        .menuStyle(.button)
        .labelStyle(.iconOnly)
        .help(title)
        .accessibilityLabel("Inspector view, \(title)")
        .fixedSize()
    }

    private var title: String { InspectorTabTitle.of(model.inspectorTab, model: model) }
}
