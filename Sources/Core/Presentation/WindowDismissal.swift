import Foundation

public enum WindowDismissal {
    public enum Stroke: String, Sendable, CaseIterable {
        case escape
        case commandW
        case shiftCommandW
    }

    public enum Role: String, Sendable, CaseIterable {
        case workspace

        case utility

        case reading
    }

    public struct Target: Sendable, Equatable {
        public let role: Role
        public let isClosable: Bool
        public let isSheet: Bool
        public let hasAttachedSheet: Bool

        public init(
            role: Role,
            isClosable: Bool = true,
            isSheet: Bool = false,
            hasAttachedSheet: Bool = false
        ) {
            self.role = role
            self.isClosable = isClosable
            self.isSheet = isSheet
            self.hasAttachedSheet = hasAttachedSheet
        }
    }

    public static func closes(_ stroke: Stroke, _ target: Target) -> Bool {
        guard target.isClosable, !target.isSheet, !target.hasAttachedSheet else { return false }

        switch stroke {
        case .shiftCommandW:
            return true
        case .commandW:
            return target.role != .workspace
        case .escape:
            return target.role == .reading
        }
    }
}
