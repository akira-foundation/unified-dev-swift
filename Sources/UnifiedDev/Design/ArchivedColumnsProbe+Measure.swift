import AppKit
import Core

extension ArchivedColumnsProbe {
    static func measure(_ window: NSWindow) -> Drawn {
        let found = identifiers(in: window.contentView)
        guard let root = window.contentView, let split = splitView(under: root) else {
            return Drawn(columns: [], identifiers: found)
        }
        let controller = split.delegate as? NSSplitViewController
        let columns = (controller?.splitViewItems ?? []).map { item in
            let view = item.viewController.view
            return Drawn.Column(
                collapsed: item.isCollapsed,
                width: view.frame.width,
                onScreen: !item.isCollapsed && view.frame.width > 1 && view.window != nil,
                ink: ink(in: view)
            )
        }
        return Drawn(columns: columns, identifiers: found)
    }
    static func splitView(under view: NSView) -> NSSplitView? {
        if let split = view as? NSSplitView, split.delegate is NSSplitViewController { return split }
        for subview in view.subviews {
            if let found = splitView(under: subview) { return found }
        }
        return nil
    }
    static func glass(_ window: NSWindow) async -> Double {
        await WindowCapture.read(window).ink
    }
    static func ink(in view: NSView) -> Double {
        guard view.frame.width > 4, view.frame.height > 4,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return 0 }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let image = bitmap.cgImage else { return 0 }
        return InkReading.of(image).ink
    }
    static func chrome(_ window: NSWindow) -> JSONValue {
        var fields: [String: JSONValue] = [:]
        fields["opaque"] = .bool(window.isOpaque)
        fields["alpha"] = .number(Double(window.alphaValue))
        fields["background"] = .string(String(describing: window.backgroundColor))
        fields["titlebarTransparent"] = .bool(window.titlebarAppearsTransparent)
        fields["titleVisibility"] = .integer(window.titleVisibility.rawValue)
        fields["styleMask"] = .integer(Int(window.styleMask.rawValue))
        fields["accessories"] = .integer(window.titlebarAccessoryViewControllers.count)
        fields["frameHeight"] = .number(Double(window.frame.height))
        if let content = window.contentView {
            fields["contentY"] = .number(Double(content.frame.origin.y))
            fields["contentHeight"] = .number(Double(content.frame.height))
            fields["contentOpaque"] = .bool(content.layer?.isOpaque ?? false)
        }
        return .object(fields)
    }
    static func identifiers(in root: Any?) -> Set<String> {
        guard let element = root as? any NSAccessibilityProtocol else { return [] }
        var result = Set<String>()
        if let identifier = element.accessibilityIdentifier() { result.insert(identifier) }
        for child in element.accessibilityChildren() ?? [] {
            result.formUnion(identifiers(in: child))
        }
        return result
    }
}
