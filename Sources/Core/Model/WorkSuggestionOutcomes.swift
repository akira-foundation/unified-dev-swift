import Foundation

public enum WorkSuggestionAdmission: Sendable, Hashable {
    case added(WorkSuggestion)
    case full(undecided: Int)

    public var suggestion: WorkSuggestion? {
        guard case .added(let suggestion) = self else { return nil }
        return suggestion
    }
}

public enum WorkSuggestionClaim: Sendable, Hashable {
    case claimed(WorkSuggestion)
    case taken(WorkSuggestion)
    case missing
}

public enum WorkSuggestionWithdrawal: Sendable, Hashable {
    case withdrawn(WorkSuggestion)
    case notYours
    case alreadyDecided(WorkSuggestion)
    case missing
}
