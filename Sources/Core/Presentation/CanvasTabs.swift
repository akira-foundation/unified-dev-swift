import Foundation

public protocol CanvasTabValue {
    var kind: CenterTabKind { get }
    var title: String { get set }
    var path: String { get set }
    var isNamed: Bool { get set }
}

public struct CanvasTabsShown<Tab: CanvasTabValue> {
    public let tabs: [Tab]
    public let index: Int
}

public enum CanvasTabs {
    public static func show<Tab: CanvasTabValue>(
        path: String, title: String?, in tabs: [Tab], making make: () -> Tab
    ) -> CanvasTabsShown<Tab> {
        var tabs = tabs
        let index: Int
        if let existing = tabs.firstIndex(where: { $0.kind == .canvas }) {
            index = existing
        } else {
            tabs.append(make())
            index = tabs.count - 1
        }
        tabs[index].path = path
        if let name = title?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            tabs[index].title = name
            tabs[index].isNamed = true
        } else {
            tabs[index].isNamed = false
        }
        return CanvasTabsShown(tabs: tabs, index: index)
    }
}
