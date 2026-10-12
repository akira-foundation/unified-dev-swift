import AppKit
import Core
import ScreenCaptureKit

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
        do {
            let shareable = try await SCShareableContent.currentProcess
            guard let target = shareable.windows.first(where: {
                $0.windowID == CGWindowID(window.windowNumber)
            }) else { return -1 }
            let configuration = SCStreamConfiguration()
            configuration.width = Int(window.frame.width)
            configuration.height = Int(window.frame.height)
            configuration.showsCursor = false
            configuration.ignoreShadowsSingleWindow = true
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: SCContentFilter(desktopIndependentWindow: target),
                configuration: configuration
            )
            return ink(in: NSBitmapImageRep(cgImage: image))
        } catch {
            return -1
        }

    }
    static func ink(in view: NSView) -> Double {
        guard view.frame.width > 4, view.frame.height > 4,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return 0 }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        return ink(in: bitmap)
    }
    static func ink(in bitmap: NSBitmapImageRep) -> Double {
        let stepX = max(1, bitmap.pixelsWide / 200)
        let stepY = max(1, bitmap.pixelsHigh / 200)
        var edges = 0
        var total = 0
        for y in stride(from: 0, to: bitmap.pixelsHigh, by: stepY) {
            var previous: NSColor?
            for x in stride(from: 0, to: bitmap.pixelsWide, by: stepX) {
                guard let found = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                defer { previous = found }
                guard let previous else { continue }
                total += 1
                let apart = abs(found.redComponent - previous.redComponent)
                    + abs(found.greenComponent - previous.greenComponent)
                    + abs(found.blueComponent - previous.blueComponent)
                if apart > 0.06 { edges += 1 }
            }
        }
        return total == 0 ? 0 : Double(edges) / Double(total)
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
