import SwiftUI

/// A window pane control, drawn the same at either edge.
///
/// Task 7 report: only the trailing, inspector-facing case is used now. The leading, sidebar-facing
/// case was a toolbar item beside the traffic lights; the system's own sidebar toggle stands there
/// now, so `edge: .leading` has no caller left. Kept rather than trimmed to one case: this is a
/// general "is this pane open" control, not a toolbar-specific one, and the leading geometry is
/// still correct if a caller needs it again.
///
/// Drawn as the sidebar's control is drawn, because the two do the same job to opposite edges of
/// one window. That reference is `NSToolbarToggleSidebarItemIdentifier`, which the SDK describes
/// as "a standard item configured to send -toggleSidebar: to the firstResponder": a plain action
/// item. `NSSplitViewController` validates it, but validation answers enabled or disabled, so
/// **AppKit gives that control no on state at all.** It is the same quiet round button whether the
/// sidebar is open or shut, and what answers "is the pane there" is the pane, a whole column wide.
///
/// So this is a `Button` rather than a `Toggle`, and it stays one: `GlassButtonStyle` took a
/// `PrimitiveButtonStyleConfiguration`, which carries no on state, so the accent plate a toggle
/// would have wanted could only come from `.toggleStyle(.button)` wrapping it, which no button
/// style can reach. That mattered while there was a plate. There is none now; see `body`.
///
/// The state a `Toggle` used to announce is put back by hand below, because it has to be: a sighted
/// reader has the pane itself, and a VoiceOver user has nothing unless this says so.
///
/// A binding rather than the app model, so the gallery can hold both states on one page.
struct WindowPaneToggle: View {
    enum Edge {
        case leading
        case trailing

        var name: String {
            switch self {
            case .leading: "Sidebar"
            case .trailing: "Inspector"
            }
        }

        var symbol: String {
            switch self {
            case .leading: "sidebar.leading"
            case .trailing: "sidebar.trailing"
            }
        }
    }

    var edge: Edge
    var isVisible: Bool
    var action: @MainActor @Sendable () -> Void
    /// Both controls use the same icon-only geometry at opposite ends of the title bar, and
    /// neither draws its own hover plate or frame: `.buttonStyle(.glass)` supplies the hit box,
    /// the hover fill and the pressed state, the way it does for every other icon-only control in
    /// this bar. The one thing left to say by hand is which colour ink the state gets, below.
    ///
    /// This stays a plain view rather than a system component because there is none to reach for:
    /// `RootView` documents a verified crash from wrapping the inspector's own split in
    /// `.inspector(isPresented:)`, the modifier that would otherwise supply a toggle automatically
    /// the way `NavigationSplitView` supplies the sidebar's. A hand-rolled `Button` styled with
    /// nothing but standard modifiers is what is left once that door is shut.
    var body: some View {
        Button(action: action) {
            Label(edge.name, systemImage: edge.symbol)
                .labelStyle(.iconOnly)
        }
        // A stable name with a spoken state, rather than a name that changes under the reader: a
        // control called "Show the changed files" one moment and "Hide" the next is a different
        // control every time it is found. The direction is in `help`, which is also the tooltip.
        .accessibilityLabel(edge.name)
        .accessibilityValue(isVisible ? "Shown" : "Hidden")
        .help(help)
    }

    private var help: String {
        switch (edge, isVisible) {
        case (.leading, true): "Hide the sidebar"
        case (.leading, false): "Show the sidebar"
        case (.trailing, true): "Hide the changed files"
        case (.trailing, false): "Show the changed files"
        }
    }
}

/// Kept as a small wrapper for the pane gallery, which presents both inspector states without an
/// app model. The live window uses `WindowPaneToggle` directly in its title bar.
struct InspectorToggle: View {
    @Binding var isVisible: Bool

    var body: some View {
        WindowPaneToggle(edge: .trailing, isVisible: isVisible) {
            isVisible.toggle()
        }
    }
}
