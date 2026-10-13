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
            configuration.width = min(Int(window.frame.width), InkReading.widest)
            configuration.height = min(Int(window.frame.height), InkReading.widest)
            configuration.showsCursor = false
            configuration.ignoreShadowsSingleWindow = true
            return InkReading.of(try await SCScreenshotManager.captureImage(
                contentFilter: SCContentFilter(desktopIndependentWindow: target),
                configuration: configuration
            ))
        } catch {
            reading.failure = Self.locked(error)
                ? "the screen is locked, and nothing can be read off the window server until it "
                    + "is unlocked: \(error)"
                : "\(error)"
            return reading
        }
    }

    static let lockedScreen = -3811

    static func locked(_ error: any Error) -> Bool {
        (error as NSError).code == Self.lockedScreen
    }
}
