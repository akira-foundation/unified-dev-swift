import AppKit

extension NSSavePanel {
    @MainActor
    func present() async -> NSApplication.ModalResponse {
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            return await beginSheetModal(for: window)
        }
        return await withCheckedContinuation { continuation in
            begin { continuation.resume(returning: $0) }
        }
    }
}
