import Foundation

public enum FindCommand {
    public enum Target: Equatable, Sendable {
        case findInPlace
        case workspaceSearch
    }

    public static func find(canFindInPlace: Bool, hasProjects: Bool) -> Target? {
        if canFindInPlace { return .findInPlace }
        return hasProjects ? .workspaceSearch : nil
    }

    public static func step(canFindInPlace: Bool) -> Target? {
        canFindInPlace ? .findInPlace : nil
    }
}
