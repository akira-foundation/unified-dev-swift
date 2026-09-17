import Foundation

public struct TreeRow: Sendable, Equatable {
    public var depth: Int
    public var isDirectory: Bool
    public var isExpanded: Bool

    public init(depth: Int, isDirectory: Bool, isExpanded: Bool) {
        self.depth = depth
        self.isDirectory = isDirectory
        self.isExpanded = isExpanded
    }
}

public enum TreeStep: Equatable, Sendable {
    case expand(Int)
    case collapse(Int)
    case move(Int)
    case none
}

public enum TreeNavigation {
    public static func step(_ key: ListKey, at index: Int?, in rows: [TreeRow]) -> TreeStep {
        guard let index, rows.indices.contains(index) else { return .none }
        let row = rows[index]

        switch key {
        case .right:
            guard row.isDirectory else { return .none }
            guard row.isExpanded else { return .expand(index) }
            let child = index + 1
            guard rows.indices.contains(child), rows[child].depth > row.depth else { return .none }
            return .move(child)

        case .left:
            if row.isDirectory, row.isExpanded { return .collapse(index) }
            guard let parent = rows[..<index].lastIndex(where: { $0.depth < row.depth }) else {
                return .none
            }
            return .move(parent)

        case .up, .down, .home, .end, .activate, .character:
            return .none
        }
    }
}
