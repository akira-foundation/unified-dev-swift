import AppKit
import Core
import ScreenCaptureKit

@MainActor
enum WindowCapture {
    static func read(_ window: NSWindow) async -> InkReading {
        var reading = InkReading()
        do {
            guard let target = try await own(window) else {
                reading.failure = "the window server does not list window \(window.windowNumber)"
                return reading
            }
            let configuration = SCStreamConfiguration()
            configuration.width = min(Int(window.frame.width), InkReading.widest)
            configuration.height = min(Int(window.frame.height), InkReading.widest)
            configuration.scalesToFit = true
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

    static func own(_ window: NSWindow) async throws -> SCWindow? {
        guard let number = CGWindowID(exactly: window.windowNumber) else { return nil }
        let shareable = try await SCShareableContent.currentProcess
        return shareable.windows.first { $0.windowID == number }
    }

    static func own(_ windows: [NSWindow]) async throws -> [SCWindow] {
        let numbers = Set(windows.compactMap { CGWindowID(exactly: $0.windowNumber) })
        let shareable = try await SCShareableContent.currentProcess
        return shareable.windows.filter { numbers.contains($0.windowID) }
    }

    static func display(of window: NSWindow) async throws -> SCDisplay? {
        guard let screen = window.screen ?? NSScreen.screens.first,
              let number = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
              ] as? CGDirectDisplayID else { return nil }
        let shareable = try await SCShareableContent.currentProcess
        return shareable.displays.first { $0.displayID == number }
    }

    static let lockedScreen = -3811

    static func locked(_ error: any Error) -> Bool {
        (error as NSError).code == Self.lockedScreen
    }
}
