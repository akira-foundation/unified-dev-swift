import AppKit
import SwiftUI
import Core

struct SearchPanelWindowOverlay: View {
    let app: AppModel
    let panel: SearchPanelModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var geometry: SearchPanelWindowGeometry { .shared }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                if panel.isOpen {
                    dim
                    card(inWindow: proxy.size.width)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(reduceMotion ? nil : Motion.pane, value: panel.isOpen)
        }
        .environment(app)
    }

    private var dim: some View {
        Rectangle()
            .fill(Palette.panelScrim)
            .contentShape(Rectangle())
            .onTapGesture { panel.close(app: app) }
            .accessibilityHidden(true)
            .transition(.opacity)
    }

    private func card(inWindow windowWidth: CGFloat) -> some View {
        Group {
            if let files = panel.files {
                FileSearchView(app: app, panel: panel, model: files)
                    .id(files.workspace.id)
                    .frame(width: SearchPanelLayout.width(inWindow: windowWidth))
            } else {
                SearchPanelView(
                    app: app,
                    panel: panel,
                    width: SearchPanelLayout.width(inWindow: windowWidth)
                )
            }
        }
        .padding(.top, geometry.titleBarHeight + SearchPanelLayout.topInset)
        .transition(.opacity)
    }
}

@MainActor
@Observable
final class SearchPanelWindowGeometry {
    static let shared = SearchPanelWindowGeometry()

    private init() {}

    private(set) var trafficLights: CGRect?

    private(set) var titleBarHeight: CGFloat = 0

    func setTitleBarHeight(_ height: CGFloat) {
        guard titleBarHeight != height else { return }
        titleBarHeight = height
    }

    func setChrome(trafficLights: CGRect?) {
        guard self.trafficLights != trafficLights else { return }
        self.trafficLights = trafficLights
    }
}

final class SearchPanelOverlayHost: NSHostingView<SearchPanelWindowOverlay> {
    private static let trafficLightPadding: CGFloat = 3

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard SearchPanelModel.shared.isOpen else { return nil }
        if let lights = SearchPanelWindowGeometry.shared.trafficLights, lights.contains(point) {
            return nil
        }
        return super.hitTest(point)
    }

    override var mouseDownCanMoveWindow: Bool { false }

    private var isWatchingWindow = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        safeAreaRegions = []
        guard let window else {
            SearchPanelWindowGeometry.shared.setChrome(trafficLights: nil)
            return
        }
        if !isWatchingWindow {
            isWatchingWindow = true
            let centre = NotificationCenter.default
            for name in [
                NSWindow.didResizeNotification,
                NSWindow.didEndLiveResizeNotification,
                NSWindow.didEnterFullScreenNotification,
                NSWindow.didExitFullScreenNotification,
            ] {
                centre.addObserver(
                    self, selector: #selector(windowGeometryChanged), name: name, object: window
                )
            }
            if let frame = superview {
                frame.postsFrameChangedNotifications = true
                centre.addObserver(
                    self,
                    selector: #selector(windowGeometryChanged),
                    name: NSView.frameDidChangeNotification,
                    object: frame
                )
            }
        }
        windowGeometryChanged()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func windowGeometryChanged() {
        matchTheFrameView()
        publishGeometry()
    }

    private func matchTheFrameView() {
        guard let frame = superview, self.frame != frame.bounds else { return }
        self.frame = frame.bounds
    }

    private func publishGeometry() {
        let geometry = SearchPanelWindowGeometry.shared
        guard let window, let frame = superview else {
            geometry.setChrome(trafficLights: nil)
            return
        }
        geometry.setTitleBarHeight(window.frame.height - window.contentLayoutRect.height)
        let buttons = [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton]
            .compactMap { window.standardWindowButton($0) }
            .filter { !$0.isHidden }
        var lights: CGRect?
        if let first = buttons.first {
            let union = buttons.dropFirst().reduce(first.convert(first.bounds, to: frame)) {
                $0.union($1.convert($1.bounds, to: frame))
            }
            lights = union.insetBy(dx: -Self.trafficLightPadding, dy: -Self.trafficLightPadding)
        }
        geometry.setChrome(trafficLights: lights)
    }
}
