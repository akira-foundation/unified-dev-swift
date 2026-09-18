import AppKit

@MainActor
enum AppMenuBarMark {
    static let image: NSImage? = {
        guard let url = Bundle.main.url(forResource: "AppMenuBar", withExtension: "pdf"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = true
        image.accessibilityDescription = "Unified Dev"
        return image
    }()
}
