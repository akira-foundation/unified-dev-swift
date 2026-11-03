import AppKit

@MainActor
enum GalleryOffscreen {
    static var isRequested: Bool {
        CommandLine.arguments.contains("--offscreen")
    }

    static let parked = NSPoint(x: -30_000, y: -30_000)

    private static var gallery: NSWindow?

    private static var isHiding = false

    static func hideWindowsAsTheyOpen() {
        guard isRequested, !isHiding else { return }
        isHiding = true
        Task { @MainActor in
            while isHiding {
                for window in NSApp.windows
                where window !== gallery && window.alphaValue > 0 {
                    window.alphaValue = 0
                }
                try? await Task.sleep(for: .milliseconds(10))
            }
        }
    }

    static func stopHiding() {
        isHiding = false
    }

    static func place(_ window: NSWindow) {
        guard isRequested else {
            window.center()
            return
        }
        gallery = window
        window.setFrameOrigin(parked)
    }

    static func park(_ window: NSWindow) {
        window.setFrameOrigin(parked)
    }

    static func show(_ window: NSWindow) {
        window.orderFrontRegardless()
        guard isRequested else { return }
        window.setFrameOrigin(parked)
    }
}
