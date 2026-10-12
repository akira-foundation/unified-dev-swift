import AppKit
import Core
import ScreenCaptureKit

@MainActor
enum WindowCapture {
    static func read(_ window: NSWindow) async -> InkReading {
        var reading = InkReading()
        do {
            let shareable = try await SCShareableContent.currentProcess
            guard let target = shareable.windows.first(where: {
                $0.windowID == CGWindowID(window.windowNumber)
            }) else {
                reading.failure = "the window server does not list window \(window.windowNumber)"
                return reading
            }
            let configuration = SCStreamConfiguration()
            configuration.width = Int(window.frame.width)
            configuration.height = Int(window.frame.height)
            configuration.showsCursor = false
            configuration.ignoreShadowsSingleWindow = true
            return InkReading.of(try await SCScreenshotManager.captureImage(
                contentFilter: SCContentFilter(desktopIndependentWindow: target),
                configuration: configuration
            ))
        } catch {
            reading.failure = "\(error)"
            return reading
        }
    }
}
