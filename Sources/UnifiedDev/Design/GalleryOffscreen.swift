import AppKit

@MainActor
enum GalleryOffscreen {
    static var isRequested: Bool {
        CommandLine.arguments.contains("--offscreen")
    }

    private static let origin = NSPoint(x: -30_000, y: -30_000)

    private static var gallery: NSWindow?

    static func hideWindowsAsTheyOpen() {
        guard isRequested else { return }
        Task { @MainActor in
            while true {
                for window in NSApp.windows where window !== gallery && window.alphaValue > 0 {
                    window.alphaValue = 0
                }
                try? await Task.sleep(for: .milliseconds(10))
            }
        }
    }

    static func place(_ window: NSWindow) {
        guard isRequested else {
            window.center()
            return
        }
        gallery = window
        window.setFrameOrigin(origin)
    }

    static func show(_ window: NSWindow) {
        window.orderFrontRegardless()
        guard isRequested else { return }
        window.setFrameOrigin(origin)
    }
}
