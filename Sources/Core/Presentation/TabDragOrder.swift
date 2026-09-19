import Foundation

public enum TabDragOrder {
    public static func live<ID: Hashable>(
        _ run: [ID], moving id: ID, centres: [ID: Double], to pointer: Double
    ) -> [ID] {
        guard run.contains(id), run.count > 1 else { return run }
        guard run.allSatisfy({ centres[$0] != nil }) else { return run }

        var others = run.filter { $0 != id }
        let index = others.filter { centres[$0]! < pointer }.count
        others.insert(id, at: min(index, others.count))
        return others
    }

    public static func moved<ID: Hashable>(_ run: [ID], moving id: ID, by step: Int) -> [ID]? {
        guard let index = run.firstIndex(of: id) else { return nil }
        let destination = index + step
        guard destination != index, run.indices.contains(destination) else { return nil }

        var order = run
        order.insert(order.remove(at: index), at: destination)
        return order
    }
}
