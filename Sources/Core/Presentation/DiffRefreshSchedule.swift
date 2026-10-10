import Foundation

public enum DiffRefreshSchedule {
    public enum Activity: Sendable, Equatable {
        case foreground
        case background
    }

    public static let tick: TimeInterval = 6

    public static let backgroundTick: TimeInterval = 30

    public static let width = 4

    public static let idleMaxAge: TimeInterval = 300

    public static let selectedMaxAge: TimeInterval = 30

    public static func tick(for activity: Activity) -> TimeInterval {
        switch activity {
        case .foreground: tick
        case .background: backgroundTick
        }
    }

    public static func priority(for activity: Activity) -> TaskPriority {
        switch activity {
        case .foreground: .userInitiated
        case .background: .utility
        }
    }

    public static func isDue(
        activity: Activity, lastRun: ContinuousClock.Instant?, now: ContinuousClock.Instant
    ) -> Bool {
        guard let lastRun else { return true }
        return now - lastRun >= .seconds(tick(for: activity))
    }

    public static func due(
        workspaces: [WorkspaceID],
        busy: Set<WorkspaceID>,
        selected: WorkspaceID? = nil,
        activity: Activity = .foreground,
        lastRefreshed: [WorkspaceID: Date],
        now: Date,
        tick: TimeInterval = tick,
        idleMaxAge: TimeInterval = idleMaxAge,
        selectedMaxAge: TimeInterval = selectedMaxAge
    ) -> [WorkspaceID] {
        if activity == .background {
            guard let selected, workspaces.contains(selected) else { return [] }
            return [selected]
        }

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
