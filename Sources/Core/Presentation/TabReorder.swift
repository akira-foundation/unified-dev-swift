import Foundation

public enum TabReorder {
    public static func apply<ID: Hashable>(_ visible: [ID], to all: [ID]) -> [ID]? {
        let drawn = Set(visible)
        guard drawn.count == visible.count else { return nil }
        let slots = all.indices.filter { drawn.contains(all[$0]) }
        guard slots.count == visible.count else { return nil }

        var order = all
        for (slot, id) in zip(slots, visible) { order[slot] = id }

        return order == all ? nil : order
    }
}
