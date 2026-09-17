import SwiftUI
import AppKit
import WebKit
import Core

final class BrowserHostView: NSView {
    private weak var page: NSView?

    func attach(_ view: NSView) {
        guard page !== view || view.superview !== self else { return }
        page?.removeFromSuperview()
        view.removeFromSuperview()
        view.frame = bounds
        view.autoresizingMask = [.width, .height]
        addSubview(view)
        page = view
        needsLayout = true
    }

    override func layout() {
        super.layout()
        page?.frame = bounds
    }
}

final class BrowserPageWebView: WKWebView {
    var paneMenu: (@MainActor () -> NSMenu)?

    var findCommand: (@MainActor (BrowserFindCommand) -> Void)?

    private var hostedPaneMenu: NSMenu?

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        super.willOpenMenu(menu, with: event)
        guard let paneMenu else { return }

        let hosted = paneMenu()
        hostedPaneMenu = hosted
        guard !hosted.items.isEmpty else { return }

        menu.addItem(.separator())
        for item in hosted.items {
            hosted.removeItem(item)
            menu.addItem(item)
        }
    }

    @objc func performFindPanelAction(_ sender: Any?) {
        guard let tag = (sender as? NSMenuItem)?.tag,
              let action = NSTextFinder.Action(rawValue: tag),
              let command = Self.command(for: action) else { return }
        findCommand?(command)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard let command = findKey(event) else { return super.performKeyEquivalent(with: event) }
        findCommand?(command)
        return true
    }

    private func findKey(_ event: NSEvent) -> BrowserFindCommand? {
        guard findCommand != nil, holdsKeyboard else { return nil }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.contains(.option), !flags.contains(.control) else { return nil }
        return BrowserFindCommand.forKey(
            event.charactersIgnoringModifiers ?? "",
            hasCommand: flags.contains(.command),
            hasShift: flags.contains(.shift)
        )
    }

    private var holdsKeyboard: Bool {
        guard let responder = window?.firstResponder as? NSView else { return false }
        return responder === self || responder.isDescendant(of: self)
    }

    private static func command(for action: NSTextFinder.Action) -> BrowserFindCommand? {
        switch action {
        case .showFindInterface: .show
        case .nextMatch: .next
        case .previousMatch: .previous
        case .hideFindInterface: .hide
        default: nil
        }
    }
}

struct BrowserWebView: NSViewRepresentable {
    var session: BrowserSession
    var paneMenu: (@MainActor () -> NSMenu)?
    var host = BrowserPaneHost()
    var viewportSize: CGSize?

    func makeNSView(context: Context) -> BrowserViewportHostView {
        let view = BrowserViewportHostView()
        view.viewportSize = viewportSize
        view.attach(session.pageView)
        wire()
        return view
    }

    func updateNSView(_ nsView: BrowserViewportHostView, context: Context) {
        nsView.viewportSize = viewportSize
        nsView.attach(session.pageView)
        wire()
    }

    private func wire() {
        session.webView.paneMenu = paneMenu
        session.host = host
    }
}
