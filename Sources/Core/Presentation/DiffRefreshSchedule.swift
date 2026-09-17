import Foundation

public enum DiffRefreshSchedule {
    public static let tick: TimeInterval = 6

    public static let width = 4

    public static let idleMaxAge: TimeInterval = 300

    public static let selectedMaxAge: TimeInterval = 30

    public static func due(
        workspaces: [WorkspaceID],
        busy: Set<WorkspaceID>,
        selected: WorkspaceID? = nil,
        lastRefreshed: [WorkspaceID: Date],
        now: Date,
        tick: TimeInterval = tick,
        idleMaxAge: TimeInterval = idleMaxAge,
        selectedMaxAge: TimeInterval = selectedMaxAge
    ) -> [WorkspaceID] {
        var due: [WorkspaceID] = []
        var stale: [(id: WorkspaceID, age: TimeInterval, place: Int)] = []

        for (place, id) in workspaces.enumerated() {
            if busy.contains(id) {
                due.append(id)
                continue
            }
            guard let last = lastRefreshed[id] else {
                due.append(id)
                continue
            }
            let age = now.timeIntervalSince(last)
            if id == selected {
                if age >= selectedMaxAge { due.append(id) }
                continue
            }
            guard age >= idleMaxAge else { continue }
            stale.append((id, age, place))
        }

        guard !stale.isEmpty else { return due }

        let idleCount = workspaces.count { !busy.contains($0) && $0 != selected }
        let perTick = max(1, Int((Double(idleCount) * tick / idleMaxAge).rounded(.up)))

        let oldest = stale
            .sorted { $0.age == $1.age ? $0.place < $1.place : $0.age > $1.age }
            .prefix(perTick)
        due.append(contentsOf: oldest.map(\.id))
        return due
    }
}
