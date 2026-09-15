import SwiftUI
import Core

/// The inspector's own toolbar, at the top of the inspector.
///
/// **Two bars, one per pane, which is what Mail does.** These controls used to be items of the
/// window's toolbar, at its trailing edge, and that edge is over the CENTRE column whenever the
/// inspector is open: measured at a 1122 point window, the picker and its group ran from x 730 to
/// x 1080 while the pane they act on began at x 793. The Mac way of dividing one toolbar by a
/// split view's divider is `NSTrackingSeparatorToolbarItem`, and it is unavailable here: the
/// divider that matters belongs to a nested `NSSplitViewController` of ours rather than to the
/// window's own split. Measured, the item was packed inline where the bar wanted it, and pointing
/// it at the outer divider instead took the window into an `AttributeGraph` cycle and drew
/// nothing. A bar inside the pane is aligned with the pane by construction.
///
/// It is the same furniture as the window's bar: the same glass capsules, the same group that
/// draws its own dividers, the same control sizes. What it is not is a second row of chrome: it
/// sits in the space the pane already keeps above its list.
struct InspectorBar: View {
    @Bindable var model: WorkspaceModel

    /// Handed in rather than read from the environment: a title bar accessory is its own SwiftUI
    /// root and the window's environment does not reach it.
    var app: AppModel

    var body: some View {
        HStack(spacing: Metrics.spacing) {
            InspectorViewPicker(model: model)
                .glassCapsule()

            Spacer(minLength: Metrics.spacingSmall)

            // One group, so the system draws the dividers between its members rather than three
            // capsules with air between them. Always all three, greyed where they mean nothing:
            // items leaving a bar move every item after them, and a control that moves under the
            // pointer as the view changes is the fault this arrangement already avoided once.
            HStack(spacing: 0) {
                InspectorToolbar.GroupingButton(model: model)
                    .frame(width: Self.hit, height: Self.hit)
                InspectorToolbar.ScopeMenu(model: model)
                    .frame(width: Self.hit, height: Self.hit)
                InspectorToolbar.MoreMenu(model: model)
                    .frame(width: Self.hit, height: Self.hit)
            }
            .glassCapsule()

            // The control that closes this pane, at the pane's own trailing edge, which is the
            // window's. It is a toolbar item while the inspector is shut, because then there is no
            // section here to put it in: see `WindowToolbar`.
            WindowPaneToggle(edge: .trailing, isVisible: true) {
                app.isInspectorVisible = false
            }
            .glassCapsule()
        }
        .buttonStyle(.plain)
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        // The window's bar draws these as glyphs and so does this one. Left to itself a `Menu`
        // here spelled its own label out, and three words in a 280 point pane pushed the group
        // off the trailing edge.
        .labelStyle(.iconOnly)
        .fixedSize()
        .controlSize(.small)
        .foregroundStyle(Palette.textSecondary)
        .padding(.horizontal, InspectorLayout.inset)
        .frame(height: InspectorLayout.barHeight)
    }

    /// The box each glyph is aimed at inside its capsule.
    private static let hit: CGFloat = 26
}

private extension View {
    /// The capsule the window's toolbar gives a group, for a bar that is not in a toolbar.
    ///
    /// Glass, and the controls inside it are plain: glass does not sample glass, measured, so a
    /// glass button on a glass plate draws no plate of its own and the group loses its rim.
    func glassCapsule() -> some View {
        padding(.horizontal, Metrics.spacingSmall)
            .frame(height: 28)
            .glassEffect(.regular, in: .capsule)
    }
}
