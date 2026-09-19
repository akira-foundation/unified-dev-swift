import Foundation

public enum WorkSuggestionCardPayload {
    private struct Body: Codable {
        let suggestionID: WorkSuggestionID

        enum CodingKeys: String, CodingKey {
            case suggestionID = "suggestion_id"
        }
    }

    public static func encode(_ id: WorkSuggestionID) -> Data {
        (try? JSONEncoder().encode(Body(suggestionID: id))) ?? Data()
    }

    public static func decode(_ payload: Data) -> WorkSuggestionID? {
        (try? JSONDecoder().decode(Body.self, from: payload))?.suggestionID
    }
}
