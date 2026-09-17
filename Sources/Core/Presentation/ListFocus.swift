import Foundation

public enum ListFocusOrigin: Sendable, Equatable {
    case mouse
    case keyboard
    case unknown
}

public struct ListFocus: Sendable, Equatable {
    public var hasKeyboard: Bool
    public var origin: ListFocusOrigin
    public var fullKeyboardAccess: Bool

    public init(
        hasKeyboard: Bool = false,
        origin: ListFocusOrigin = .unknown,
        fullKeyboardAccess: Bool = false
    ) {
        self.hasKeyboard = hasKeyboard
        self.origin = origin
        self.fullKeyboardAccess = fullKeyboardAccess
    }

    public var showsRing: Bool {
        guard hasKeyboard else { return false }
        if fullKeyboardAccess { return true }
        return origin != .mouse
    }
}
