import Foundation

public enum MenuLayout {
    public static let maxHeight: CGFloat = 240

    public static let minimumHeight: CGFloat = 100

    public enum Placement: Equatable, Sendable {
        case above(room: CGFloat)
        case below(room: CGFloat)

        public var room: CGFloat {
            switch self {
            case .above(let room), .below(let room): room
            }
        }

        public var menuHeight: CGFloat {
            min(MenuLayout.maxHeight, room)
        }

        public var isBelow: Bool {
            if case .below = self { return true }
            return false
        }
    }

    public static func placement(above: CGFloat, below: CGFloat) -> Placement {
        let aboveRoom = max(above, 0)
        let belowRoom = max(below, 0)
        if aboveRoom >= minimumHeight || aboveRoom >= belowRoom {
            return .above(room: aboveRoom)
        }
        return .below(room: belowRoom)
    }
}
