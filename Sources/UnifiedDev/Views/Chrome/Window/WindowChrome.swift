import AppKit
import SwiftUI

/// Adds the workspace's own strip to the title bar.
///
/// Task 7 report: this used to hide AppKit's own title text as well, so that
/// `WindowTitleControl`'s toolbar item was the only one on screen. `WindowTitleControl` is gone;
/// AppKit's own title, positioned and drawn by AppKit, is the one title the window has now.
///
/// **What this used to also do, and no longer does.** It set `titlebarAppearsTransparent = true`
/// and painted `window.backgroundColor` with a named colour, `Palette.sidebarNSColor`, so the
/// title bar would match a hand-painted sidebar underneath it. Building against the macOS 26 SDK
/// gives the toolbar its own glass and the window its own material for free; painting a colour
/// behind a transparent title bar was this app fighting that rather than taking it. Both lines are
/// gone, and the title bar is the system's own again.
///
/// There is no title bar accessory any more. See
/// that file for why an accessory rather than content drawn under a transparent title bar.
struct WindowChrome: ViewModifier {
    /// Handed in rather than read from the environment. This modifier is applied OUTSIDE the
    /// `.environment(model)` that wraps the window's content, so it is an ancestor of the value
    /// rather than a descendant of it, and reading it there is a crash rather than a nil. Its
    /// neighbours in `UnifiedDevApp` take the model the same way for the same reason.
    let app: AppModel

    @State private var window: NSWindow?

    func body(content: Content) -> some View {
        content
            .background(WindowAccessor(window: $window))
            .onChange(of: window, initial: true) { _, _ in apply() }
    }

    private func apply() {
        guard let window else { return }
        // AppKit's own title text is visible again. It used to be hidden here so that
        // `WindowTitleControl`'s own toolbar item could be the window's only title; that control
        // is gone, `navigationTitle` is no longer removed from the toolbar in `RootView`, and this
        // is the setting `NSWindow` starts with regardless, kept explicit so the next reader does
        // not have to wonder whether something upstream still turns it off.
        window.titleVisibility = .visible
        // Opaque, on its own ground. Every pane in this window stopped painting a ground of its
        // own, which is what finally made the app one tone; what it also did was leave the window
        // see-through, so every material in it sampled the desktop. On a light wallpaper that is
        // why the completion menu, the glass buttons and the capsules came out pale with the
        // app's dark ink on them. This says which surface the window is, and nothing else paints.
        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
        addStrip(to: window)
    }

    private func addStrip(to window: NSWindow) {
        // The window is checked as well as our own state. A `@State` that comes back empty because
        // the scene was rebuilt would otherwise put a second strip in the same title bar.
        // Measured before the accessory is added, because `contentLayoutRect` is what the title
        // bar leaves over and an accessory of our own would then be measuring itself.
        let height = window.frame.height - window.contentLayoutRect.height
        guard height > 0 else { return }

        // The search panel hangs its card below the title bar and needs this same number, and
        // this is the one place in the app that measures it correctly: asked again once the strip
        // is in, `contentLayoutRect` answers 152 for a 52 point bar, because an accessory is part
        // of what the title bar leaves over. See `SearchPanelWindowGeometry.titleBarHeight`.
        SearchPanelWindowGeometry.shared.setTitleBarHeight(height)

        // No accessory any more, and taking it out is what gave the inspector's toolbar items
        // their room back.
        //
        // It existed to draw a rule of ours in the title bar, and a trailing accessory INDENTS the
        // toolbar by its own width: at the inspector's 380 points that is 380 points the bar
        // cannot lay items out in, and the inspector's picker and its group were pushed into the
        // overflow chevron. The rule went with the columns changing anyway, since the window's own
        // split is what separates them now. What is left of this measurement is the title bar's
        // height, which the search panel needs and which is read above.
    }
}

extension View {
    /// Named `configuresTitleBar` rather than `paintsTitleBar`, which this was called until it
    /// painted a colour of its own behind a transparent title bar. It no longer does either of
    /// those things: see `WindowChrome` for what was removed and why.
    func configuresTitleBar(_ app: AppModel) -> some View {
        modifier(WindowChrome(app: app))
    }
}
