import Foundation

public struct TranscriptSuggestions: Equatable, Sendable {
    private var byID: [WorkSuggestionID: WorkSuggestion]

    public init(_ suggestions: [WorkSuggestion] = []) {
        byID = Dictionary(
            suggestions.lazy.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest }
        )
    }

    public func card(at payload: Data) -> WorkSuggestion? {
        guard let id = WorkSuggestionCardPayload.decode(payload) else { return nil }
        return byID[id]
    }
}
