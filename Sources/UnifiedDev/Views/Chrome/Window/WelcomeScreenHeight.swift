import AppKit
import Observation
import SwiftUI

extension EnvironmentValues {
    @Entry var welcomeVisibleHeight: CGFloat?
}

@MainActor
@Observable
final class WelcomeScreenHeight {
    private(set) var visible: CGFloat?

    @ObservationIgnored private weak var window: NSWindow?
    @ObservationIgnored nonisolated(unsafe) private var watch: [NSObjectProtocol] = []

    deinit {
        watch.forEach(NotificationCenter.default.removeObserver)
    }

    func read(from window: NSWindow?) {
        guard window !== self.window else {
            refresh()
            return
        }
        self.window = window
        rewatch()
        refresh()
    }

    private func rewatch() {
        watch.forEach(NotificationCenter.default.removeObserver)
        watch = []
        guard let window else { return }
        watch = [
            observing(NSWindow.didChangeScreenNotification, from: window),
            observing(NSApplication.didChangeScreenParametersNotification, from: nil),
        ]
    }

    private func observing(_ name: Notification.Name, from object: Any?) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    private func refresh() {
        let height = window?.screen?.visibleFrame.height
        guard visible != height else { return }
        visible = height
    }
}

struct WelcomeScreenScope<Content: View>: View {
    let screen: WelcomeScreenHeight
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .environment(\.welcomeVisibleHeight, screen.visible)
    }
}
