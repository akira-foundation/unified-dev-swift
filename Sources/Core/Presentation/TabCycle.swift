import Foundation

public enum TabCycle {
    public static func next<Tab: Equatable>(
        from current: Tab?, in tabs: [Tab], offset: Int
    ) -> Tab? {
        guard tabs.count > 1 else { return nil }
        guard let current, let index = tabs.firstIndex(of: current) else { return tabs.first }

        let count = tabs.count
        let moved = ((index + offset) % count + count) % count
        return moved == index ? nil : tabs[moved]
    }

    public static func tab<Tab>(at ordinal: Int, in tabs: [Tab]) -> Tab? {
        guard (1...9).contains(ordinal), !tabs.isEmpty else { return nil }
        if ordinal == lastOrdinal { return tabs.last }
        return ordinal <= tabs.count ? tabs[ordinal - 1] : nil
    }

    public static func numbered<Tab: Hashable>(_ tabs: [Tab]) -> [Numbered<Tab>] {
        tabs.enumerated().map { index, tab in
            if index == tabs.count - 1, tabs.count >= lastOrdinal {
                return Numbered(tab: tab, ordinal: lastOrdinal)
            }
            return Numbered(tab: tab, ordinal: index < lastOrdinal - 1 ? index + 1 : nil)
        }
    }

    public struct Numbered<Tab: Hashable>: Hashable, Identifiable, Sendable where Tab: Sendable {
        public let tab: Tab
        public let ordinal: Int?

        public var id: Tab { tab }
    }

    private static let lastOrdinal = 9
}
