import Foundation

public enum FileBarLayout {
    public static let reserve: CGFloat = 170

    public static let floor: CGFloat = 44

    static let characterWidth: CGFloat = 6

    static let separatorWidth: CGFloat = 10

    public struct FolderCrumbs: Equatable, Sendable {
        public let components: [String]

        public let isElided: Bool

        public var isEmpty: Bool { components.isEmpty }

        public init(components: [String], isElided: Bool) {
            self.components = components
            self.isElided = isElided
        }
    }

    public static func folderWidth(width: CGFloat) -> CGFloat {
        max(width - reserve, 0)
    }

    public static func crumbs(for directory: String, width: CGFloat) -> FolderCrumbs {
        let budget = folderWidth(width: width)
        let components = directory.split(separator: "/").map(String.init)
        guard budget >= floor, !components.isEmpty else {
            return FolderCrumbs(components: [], isElided: false)
        }

        var kept = 0
        var spent: CGFloat = 0
        for component in components.reversed() {
            let cost = CGFloat(component.count) * characterWidth + separatorWidth
            if kept > 0, spent + cost > budget { break }
            spent += cost
            kept += 1
        }

        return FolderCrumbs(
            components: Array(components.suffix(kept)),
            isElided: kept < components.count
        )
    }
}
