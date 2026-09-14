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
/// The trailing end of the same strip is `TitleBarStrip`, added as a title bar accessory. See
/// that file for why an accessory rather than content drawn under a transparent title bar.
struct WindowChrome: ViewModifier {
    /// Handed in rather than read from the environment. This modifier is applied OUTSIDE the
    /// `.environment(model)` that wraps the window's content, so it is an ancestor of the value
    /// rather than a descendant of it, and reading it there is a crash rather than a nil. Its
    /// neighbours in `UnifiedDevApp` take the model the same way for the same reason.
    let app: AppModel

    @State private var window: NSWindow?
    @State private var strip: TitleBarStripController?

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
        addStrip(to: window)
    }

    private func addStrip(to window: NSWindow) {
        // The window is checked as well as our own state. A `@State` that comes back empty because
        // the scene was rebuilt would otherwise put a second strip in the same title bar.
        guard strip == nil,
              !window.titlebarAccessoryViewControllers.contains(where: { $0 is TitleBarStripController })
        else { return }
        // Measured before the accessory is added, because `contentLayoutRect` is what the title
        // bar leaves over and an accessory of our own would then be measuring itself.
        let height = window.frame.height - window.contentLayoutRect.height
        guard height > 0 else { return }

        // The search panel hangs its card below the title bar and needs this same number, and
        // this is the one place in the app that measures it correctly: asked again once the strip
        // is in, `contentLayoutRect` answers 152 for a 52 point bar, because an accessory is part
        // of what the title bar leaves over. See `SearchPanelWindowGeometry.titleBarHeight`.
        SearchPanelWindowGeometry.shared.setTitleBarHeight(height)

        let controller = TitleBarStripController(app: app, height: height)
        window.addTitlebarAccessoryViewController(controller)
        strip = controller
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
