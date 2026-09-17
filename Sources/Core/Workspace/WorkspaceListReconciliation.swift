import Foundation

public enum WorkspaceListReconciliation {
    public static func reconciled(
        held: [Workspace],
        snapshot: [Workspace],
        fresh: [Workspace]
    ) -> [Workspace] {
        let wasHeld = Dictionary(snapshot.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let isStored = Dictionary(fresh.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        return held.map { row in
            guard let stored = isStored[row.id], wasHeld[row.id] == row else { return row }
            return stored
        }
    }

    public static func afterStoreReload(fresh: [Workspace], archiving: Set<WorkspaceID>) -> [Workspace] {
        guard !archiving.isEmpty else { return fresh }
        return fresh.filter { !archiving.contains($0.id) }
    }
}
