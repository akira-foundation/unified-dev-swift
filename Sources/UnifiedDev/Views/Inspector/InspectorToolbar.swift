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
        // One button with the current view on it, not three segments. A segmented control grows
        // with its longest label and puts three words in a bar whose other items are single
        // glyphs; the toolbar pattern for a choice is a pop-up, which is what the project filter
        // beside it already is.
        picker
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
    }

    /// Whichever tabs this workspace has, rather than all three. Checks is only offered when
    /// GitHub has reported a run for the branch, so a workspace with no pull request draws two
    /// segments and no gap where a third used to be. See `InspectorTab.available`.
    private var picker: some View {
        Picker("Inspector view", selection: $model.inspectorTab) {
            ForEach(model.availableInspectorTabs, id: \.self) { tab in
                Text(InspectorTabTitle.of(tab, model: model)).tag(tab)
            }
        }
    }
}
