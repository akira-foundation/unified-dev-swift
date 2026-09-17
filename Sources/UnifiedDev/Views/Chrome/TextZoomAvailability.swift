import AppKit
import Observation

@MainActor
@Observable
final class TextZoomAvailability {
    static let shared = TextZoomAvailability()

    private(set) var canZoomIn = true
    private(set) var canZoomOut = true
    private(set) var canResetSize = false

    private init() {
        for name in [NSWindow.didUpdateNotification, UserDefaults.didChangeNotification] {
            // swiftlint:disable:next discarded_notification_center_observer
            NotificationCenter.default.addObserver(
                forName: name, object: nil, queue: .main
            ) { _ in
                Task { @MainActor in TextZoomAvailability.shared.refresh() }
            }
        }
    }

    private func refresh() {
        let zoomIn = TextZoom.canZoomIn
        let zoomOut = TextZoom.canZoomOut
        let reset = TextZoom.canResetSize
        if canZoomIn != zoomIn { canZoomIn = zoomIn }
        if canZoomOut != zoomOut { canZoomOut = zoomOut }
        if canResetSize != reset { canResetSize = reset }
    }
}
