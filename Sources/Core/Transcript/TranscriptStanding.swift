import Foundation

public enum TranscriptStanding: Sendable, Equatable {
    case there
    case gone
    case unanswerable

    public static func of(sessionID: SessionID, in store: Store) async -> TranscriptStanding {
        do {
            return try await store.session(id: sessionID) == nil ? .gone : .there
        } catch {
            return .unanswerable
        }
    }

    public static func complaint(about error: any Error) -> String {
        guard let sqlite = error as? SQLiteError else { return error.readableMessage }
        let message = sqlite.message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return "The database refused the write without saying why." }
        return message.hasSuffix(".") ? message : message + "."
    }
}
