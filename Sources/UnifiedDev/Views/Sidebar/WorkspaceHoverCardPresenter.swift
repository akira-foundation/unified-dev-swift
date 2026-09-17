import AppKit
import SwiftUI
import Core

@MainActor
final class WorkspaceHoverCardPresenter {
    static let shared = WorkspaceHoverCardPresenter()

    enum Source: Hashable {
        case workspaceRow(WorkspaceID)
        case pullRequestBand(WorkspaceID)
    }

    private var hovered: Source?
    private var pending: Task<Void, Never>?
    private var panel: NSPanel?
    private var hosting: NSHostingView<WorkspaceHoverCardView>?
    private var observers: [any NSObjectProtocol] = []
    private var monitor: Any?

    private init() {
        watchForDismissal()
    }

    func pointerEntered(
        _ source: Source,
        card: @escaping @MainActor () -> WorkspaceHoverCard?,
        anchor: @escaping @MainActor () -> CGRect?,
        side: HoverCardPlacement.Side = .trailing
    ) {
        guard hovered != source else { return }
        hovered = source
        pending?.cancel()
        hide()

        pending = Task { [weak self] in
            try? await Task.sleep(for: Motion.hoverCardDelay)
            guard !Task.isCancelled, let self, self.hovered == source else { return }
            guard let card = card(), let anchor = anchor() else { return }
            self.show(card, at: anchor, side: side)
        }
    }

    func pointerExited(_ source: Source) {
        guard hovered == source else { return }
        dismiss()
    }

    func dismiss() {
        hovered = nil
        pending?.cancel()
        pending = nil
        hide()
    }

    private func show(_ card: WorkspaceHoverCard, at anchor: CGRect, side: HoverCardPlacement.Side) {
        guard let parent = NSApp.keyWindow, parent.isVisible else { return }
        guard let screen = parent.screen ?? NSScreen.main else { return }

        let panel = panel ?? makePanel()
        self.panel = panel

        let view = WorkspaceHoverCardView(card: card)
        if let hosting {
            hosting.rootView = view
        } else {
            let hosting = NSHostingView(rootView: view)
            panel.contentView = hosting
            self.hosting = hosting
        }

        guard let hosting else { return }
        hosting.layoutSubtreeIfNeeded()
        let fitting = hosting.fittingSize
        let size = CGSize(
            width: HoverCardWidth.fits(content: fitting.width),
            height: fitting.height
        )

        panel.setFrame(
            HoverCardPlacement.frame(
                anchor: anchor, size: size, visible: screen.visibleFrame, side: side
            ),
            display: false
        )
        panel.invalidateShadow()

        guard panel.parent !== parent else {
            panel.orderFront(nil)
            return
        }
        panel.parent?.removeChildWindow(panel)
        parent.addChildWindow(panel, ordered: .above)
        fadeIn(panel)
    }

    private func hide() {
        guard let panel, panel.isVisible else { return }
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: CGSize(width: 1, height: 1)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.ignoresMouseEvents = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.animationBehavior = .none
        panel.collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
        return panel
    }

    private func fadeIn(_ panel: NSPanel) {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            panel.alphaValue = 1
            return
        }
        panel.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Motion.hoverSeconds
            panel.animator().alphaValue = 1
        }
    }

    private func watchForDismissal() {
        let centre = NotificationCenter.default
        for name in [
            NSScrollView.willStartLiveScrollNotification,
            NSWindow.didResignKeyNotification,
            NSWindow.willBeginSheetNotification,
            NSWindow.willMiniaturizeNotification,
            NSWindow.willCloseNotification,
            NSMenu.didBeginTrackingNotification,
            NSApplication.didResignActiveNotification,
        ] {
            let observer = centre.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { WorkspaceHoverCardPresenter.shared.dismiss() }
            }
            observers.append(observer)
        }

        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
        ) { event in
            MainActor.assumeIsolated { WorkspaceHoverCardPresenter.shared.dismiss() }
            return event
        }
    }
}

@MainActor
final class HoverCardAnchor {
    fileprivate weak var view: NSView?

    var screenFrame: CGRect? {
        guard let view, let window = view.window else { return nil }
        return window.convertToScreen(view.convert(view.bounds, to: nil))
    }
}

struct HoverCardAnchorReader: NSViewRepresentable {
    var anchor: HoverCardAnchor

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        anchor.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        anchor.view = nsView
    }
}
