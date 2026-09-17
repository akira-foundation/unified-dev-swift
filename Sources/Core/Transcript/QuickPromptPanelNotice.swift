import Foundation

public enum QuickPromptPanelNotice: Equatable, Sendable {
    case noMatches(String)
    case loading
    case nothingYet
}

extension QuickPromptPanelMatches {
    public func notice(isLoaded: Bool) -> QuickPromptPanelNotice? {
        guard isEmpty else { return nil }
        if !query.isEmpty { return .noMatches(query) }
        return isLoaded ? .nothingYet : .loading
    }

    public var showsProjectHeading: Bool { !project.isEmpty }
}
