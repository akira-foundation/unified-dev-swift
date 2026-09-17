import Foundation

public enum SidebarReorder {
    public struct Change: Equatable, Sendable {
        public var id: WorkspaceID
        public var sortOrder: Int
        public var pinned: Bool

        public init(id: WorkspaceID, sortOrder: Int, pinned: Bool) {
            self.id = id
            self.sortOrder = sortOrder
            self.pinned = pinned
        }
    }

    public static func drawn(_ workspaces: [Workspace]) -> [Workspace] {
        workspaces.sorted { lhs, rhs in
            if lhs.pinned != rhs.pinned { return lhs.pinned }
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.createdAt < rhs.createdAt
        }
    }

    public static func moving<Element>(
        _ elements: [Element], from: IndexSet, to: Int
    ) -> [Element] {
        let block = from.sorted().map { elements[$0] }
        let taken = from.filter { $0 < to }.count
        var result = elements
        for offset in from.sorted(by: >) { result.remove(at: offset) }
        result.insert(contentsOf: block, at: max(0, min(to - taken, result.count)))
        return result
    }

    public static func move(
        visible: [Workspace], all: [Workspace], from: IndexSet, to: Int
    ) -> [Change] {
        let drawnVisible = visible.map(\.id)
        guard from.allSatisfy({ drawnVisible.indices.contains($0) }) else { return [] }

        let afterMove = moving(drawnVisible, from: from, to: to)
        let moved = from.map { drawnVisible[$0] }
        let movedIDs = Set(moved)
        guard !movedIDs.isEmpty else { return [] }

        guard let head = afterMove.firstIndex(where: { movedIDs.contains($0) }) else { return [] }
        let tail = head + moved.count - 1
        let anchorBefore = head > 0 ? afterMove[head - 1] : nil
        let anchorAfter = tail + 1 < afterMove.count ? afterMove[tail + 1] : nil

        var order = drawn(all).map(\.id)
        let block = order.filter { movedIDs.contains($0) }
        order.removeAll { movedIDs.contains($0) }

        let insertion: Int
        if let anchorBefore, let index = order.firstIndex(of: anchorBefore) {
            insertion = index + 1
        } else if let anchorAfter, let index = order.firstIndex(of: anchorAfter) {
            insertion = index
        } else {
            return []
        }
        order.insert(contentsOf: block, at: insertion)

        let stored = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let pinnedNow = pinned(after: order, moved: movedIDs, stored: stored)

        return order.enumerated().compactMap { index, id in
            guard let workspace = stored[id] else { return nil }
            let wantsPinned = pinnedNow[id] ?? workspace.pinned
            guard workspace.sortOrder != index || workspace.pinned != wantsPinned else { return nil }
            return Change(id: id, sortOrder: index, pinned: wantsPinned)
        }
    }

    private static func pinned(
        after order: [WorkspaceID], moved: Set<WorkspaceID>, stored: [WorkspaceID: Workspace]
    ) -> [WorkspaceID: Bool] {
        guard let head = order.firstIndex(where: { moved.contains($0) }) else { return [:] }
        let tail = order.lastIndex(where: { moved.contains($0) }) ?? head

        let neighbour = tail + 1 < order.count ? order[tail + 1] : (head > 0 ? order[head - 1] : nil)
        guard let neighbour, let workspace = stored[neighbour] else { return [:] }

        var answer: [WorkspaceID: Bool] = [:]
        for id in order where moved.contains(id) { answer[id] = workspace.pinned }
        return answer
    }
}

extension SidebarReorder {
    public enum Row: Equatable, Hashable, Sendable {
        case project(RepoID)
        case workspace(id: WorkspaceID, projectID: RepoID)
        case notice(projectID: RepoID)
        case subagent(projectID: RepoID)
        case crew(projectID: RepoID)
        case pending(projectID: RepoID)

        func trails(_ projectID: RepoID) -> Bool {
            switch self {
            case .subagent(let owner), .crew(let owner), .pending(let owner): owner == projectID
            case .project, .workspace, .notice: false
            }
        }
    }

    public enum Destination: Equatable, Sendable {
        case nothing

        case project(id: RepoID, to: Int)

        case workspace(projectID: RepoID, from: IndexSet, to: Int, landedOutside: Bool)
    }

    public struct ProjectChange: Equatable, Sendable {
        public var id: RepoID
        public var sortOrder: Int

        public init(id: RepoID, sortOrder: Int) {
            self.id = id
            self.sortOrder = sortOrder
        }
    }

    public static func destination(rows: [Row], from: IndexSet, to: Int) -> Destination {
        guard from.allSatisfy({ rows.indices.contains($0) }), (0...rows.count).contains(to) else {
            return .nothing
        }
        guard let grabbed = from.min() else { return .nothing }

        switch rows[grabbed] {
        case .notice, .subagent, .crew, .pending:
            return .nothing

        case .project(let id):
            guard from.count == 1 else { return .nothing }
            return .project(id: id, to: projectOffset(rows: rows, at: to))

        case .workspace(_, let projectID):
            let owned = workspaceOffsets(rows: rows, projectID: projectID)
            guard let run = workspaceRun(rows: rows, projectID: projectID),
                  from.allSatisfy({ owned.contains($0) }) else { return .nothing }
            let landing = min(max(to, run.lowerBound), run.upperBound)
            return .workspace(
                projectID: projectID,
                from: IndexSet(from.compactMap { owned.firstIndex(of: $0) }),
                to: owned.filter { $0 < landing }.count,
                landedOutside: landing != to
            )
        }
    }

    public static func move(projects: [Repo], id: RepoID, to: Int) -> [ProjectChange] {
        move(projects: projects, visible: projects.map(\.id), id: id, to: to)
    }

    public static func move(
        projects: [Repo], visible: [RepoID], id: RepoID, to: Int
    ) -> [ProjectChange] {
        guard let index = visible.firstIndex(of: id), (0...visible.count).contains(to) else { return [] }
        let moved = moving(visible, from: IndexSet(integer: index), to: to)

        let visibleIDs = Set(visible)
        let stored = Dictionary(projects.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        guard visibleIDs.count == visible.count, visible.allSatisfy({ stored[$0] != nil }) else { return [] }
        var replacements = moved.makeIterator()
        let ordered = projects.map { repo in
            guard visibleIDs.contains(repo.id), let next = replacements.next() else { return repo }
            return stored[next] ?? repo
        }
        return ordered.enumerated().compactMap { offset, repo in
            guard repo.sortOrder != offset else { return nil }
            return ProjectChange(id: repo.id, sortOrder: offset)
        }
    }

    private static func projectOffset(rows: [Row], at flat: Int) -> Int {
        var boundaries: [Int] = []
        for (offset, row) in rows.enumerated() {
            if case .project = row { boundaries.append(offset) }
        }
        boundaries.append(rows.count)

        var best = 0
        var distance = Int.max
        for (index, boundary) in boundaries.enumerated() where abs(boundary - flat) < distance {
            distance = abs(boundary - flat)
            best = index
        }
        return best
    }

    private static func workspaceOffsets(rows: [Row], projectID: RepoID) -> [Int] {
        rows.indices.filter { offset in
            if case .workspace(_, let owner) = rows[offset] { return owner == projectID }
            return false
        }
    }

    private static func workspaceRun(rows: [Row], projectID: RepoID) -> Range<Int>? {
        let offsets = workspaceOffsets(rows: rows, projectID: projectID)
        guard let first = offsets.first, var last = offsets.last else { return nil }
        while rows.indices.contains(last + 1), rows[last + 1].trails(projectID) { last += 1 }
        return first..<(last + 1)
    }
}
