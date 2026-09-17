import AppKit

enum PaneSymbol {
    static let splitRight = "square.split.2x1"
    static let splitDown = "square.split.1x2"
    static let closePane = "xmark.rectangle"
    static let closeTab = "xmark"
    static let rename = "pencil"
    static let zoomIn = "arrow.up.left.and.arrow.down.right"
    static let zoomOut = "arrow.down.right.and.arrow.up.left"

    static func image(_ name: String, label: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: label)
    }
}
