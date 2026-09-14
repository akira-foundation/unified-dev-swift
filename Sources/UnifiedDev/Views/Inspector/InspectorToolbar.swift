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
struct InspectorToolbar: View {
    @Bindable var model: WorkspaceModel
    @Environment(AppModel.self) private var app

    /// Shared with `ChangedFileList` through the same defaults key, and outliving the launch
    /// because a user who thinks in folders thinks in folders tomorrow too.
    @AppStorage(ChangedFilePresentation.storageKey)
    private var isTree = ChangedFilePresentation.defaultsToTree

    var body: some View {
        trailing
    }

    /// One cluster, spaced the way a toolbar spaces related buttons rather than the way a row
    /// spaces unrelated ones. The points that saves are what let the segmented control survive at
    /// the pane's default width instead of dropping to its pop-up form.
    private var trailing: some View {
        HStack(spacing: Metrics.spacingTight) {
            if model.inspectorTab == .changes {
                // No plate of its own. The toolbar section around it is the visible container,
                // which is what the toolbar guidance asks for, and the state is said by the
                // symbol itself: filled while the grouping is on. A prominent glass button here
                // put a saturated accent capsule inside the section's own plate.
                Button { isTree.toggle() } label: {
                    Image(systemName: isTree ? "folder.fill" : "folder")
                }
                .buttonStyle(.borderless)
                .disabled(model.changedFiles.isEmpty)
                .accessibilityLabel("Group changes by folder")
                .accessibilityAddTraits(isTree ? .isSelected : [])
                .help(
                    isTree
                        ? "Show the changed files as a flat list"
                        : "Group the changed files by folder"
                )

                // What the list is measured from. On this tab only, because it is the only pane
                // the scope means anything for: the file tree is the whole worktree and the checks
                // list is GitHub's. Which scope is in force is said by the band under this row
                // rather than in it, for the width reason `DiffScopeBand` spells out.
                Menu {
                    DiffScopeMenuItems(model: model)
                } label: {
                    Label(
                        "What the changes are measured from",
                        systemImage: "line.3.horizontal.decrease"
                    )
                }
                .labelStyle(.iconOnly)
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .controlSize(.small)
                .fixedSize()
                .help("What the changes are measured from")
                // One glyph, in one colour, whichever scope is in force. It carried
                // `.foregroundStyle(Palette.accent)` while narrowed for a while; photographed in
                // both states the two glyphs came out at exactly the same grey, because a
                // borderless `Menu` is an `NSPopUpButton` and a foreground style set out here does
                // not reach the image it draws. `.symbolVariant(.fill)` does reach it, and a
                // filled disc in a row of outlines is louder than this control has any business
                // being. The band under this row is what says the list is narrowed, and it says it
                // in a sentence rather than by a shade of a glyph nobody would notice.
            }

            // No Refresh. The list keeps itself current: `AppModel`'s poll re-reads the selected
            // workspace's changed files while the app is frontmost, and a finished turn re-reads
            // them at once. A button asking the reader to do the app's job was only ever covering
            // for that not being true.
            //
            // The items themselves are `WorktreeMenuItems`, which is a view of its own so that
            // this menu can be photographed. See its head.
            Menu {
                WorktreeMenuItems(workspace: model.workspace, pullRequest: model.pullRequest)
            } label: {
                Label("More for this worktree", systemImage: "ellipsis")
            }
            .labelStyle(.iconOnly)
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .controlSize(.small)
            .fixedSize()
            .help("More for this worktree")

            // The inspector's own toggle, at the trailing end of this trailing cluster, the way
            // the sidebar's system toggle lives inside the sidebar's own top corner rather than in
            // the window's toolbar. `WindowToolbar` keeps a copy of this same control for when the
            // inspector is closed, because that is the only way back in once this one is gone with
            // the pane it lives in.
            WindowPaneToggle(
                edge: .trailing,
                isVisible: app.isInspectorVisible
            ) {
                app.isInspectorVisible.toggle()
            }
        }
    }

    /// **The number is the diff's, and it does not follow the filter field under this row.**
    ///
    /// This is the tab's name rather than the list's heading, and a name that changed as somebody
    /// typed would move the segment out from under a click already on its way to it, which is the
    /// same reason `InspectorTab.available` puts the conditional tab last. It also answers a
    /// different question: how much the agent changed is worth knowing while you are hunting for
    /// one file inside it, and the field holding a word is what says the list below is showing
    /// fewer.
    private func title(for tab: InspectorTab) -> String {
        InspectorTabTitle.of(tab, model: model)
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
        ViewThatFits(in: .horizontal) {
            picker.pickerStyle(.segmented).fixedSize()
            picker.pickerStyle(.menu).fixedSize()
        }
        .labelsHidden()
        .controlSize(.small)
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
