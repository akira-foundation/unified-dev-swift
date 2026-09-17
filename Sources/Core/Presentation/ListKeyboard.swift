import Foundation

public enum ListKey: Equatable, Sendable {
    case up
    case down
    case home
    case end
    case left
    case right
    case activate
    case character(Character)
}

public enum ListNavigation {
    public static func destination(for key: ListKey, from current: Int?, count: Int) -> Int? {
        guard count > 0 else { return nil }

        switch key {
        case .down:
            return current.map { min($0 + 1, count - 1) } ?? 0
        case .up:
            return current.map { max($0 - 1, 0) } ?? count - 1
        case .home:
            return 0
        case .end:
            return count - 1
        case .left, .right, .activate, .character:
            return nil
        }
    }
}

public enum ListKeyOutcome: Equatable, Sendable {
    case move(Int)
    case activate
    case handled
    case ignored
}

public struct ListKeyboard: Sendable, Equatable {
    private var typeSelect = TypeSelect()

    public init() {}

    public mutating func outcome(
        for key: ListKey,
        titles: [String],
        current: Int?,
        at now: Date = Date()
    ) -> ListKeyOutcome {
        switch key {
        case .character(let character):
            guard TypeSelect.isTypeSelect(character) else { return .ignored }
            let prefix = typeSelect.accept(character, at: now)
            guard let index = TypeSelect.match(prefix, in: titles, from: current) else {
                return .handled
            }
            return .move(index)

        case .activate:
            return current == nil ? .ignored : .activate

        case .left, .right:
            return .ignored

        case .up, .down, .home, .end:
            typeSelect.clear()
            guard let index = ListNavigation.destination(
                for: key, from: current, count: titles.count
            ) else {
                return .ignored
            }
            return index == current ? .handled : .move(index)
        }
    }

    public mutating func forgetTyping() {
        typeSelect.clear()
    }
}
