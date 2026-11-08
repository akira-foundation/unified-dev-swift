import Foundation

public enum AgentAccountAssignment {
    public static let noDatabase = "Unified Dev has no database open."

    public struct UnknownTarget: Error, Sendable, Equatable {
        public let sentence: String
    }

    public static func target(repoID: RepoID?) -> Result<RepoID, UnknownTarget> {
        guard let repoID else { return .failure(UnknownTarget(sentence: "This project is not known.")) }
        return .success(repoID)
    }

    public static func saveFailure(_ detail: String) -> String {
        "Could not save the account: \(detail)"
    }

    public static func choose(_ chosen: ChosenAgentAccount, forRepo id: RepoID, in store: Store) async throws {
        try await remember(chosen.home, in: store)
        try await store.chooseAgentAccount(chosen, forRepo: id)
    }

    public static func choose(
        _ chosen: ChosenAgentAccount, forProfile id: ProfileID, in store: Store
    ) async throws {
        try await remember(chosen.home, in: store)
        try await store.chooseAgentAccount(chosen, forProfile: id)
    }

    public static func remember(_ home: AgentAccountHome?, in store: Store) async throws {
        guard let home, home.isDefault else { return }
        try await store.addIfMissing(AgentAccountRow(
            id: home.id,
            provider: home.provider,
            directory: home.directory.path,
            isDefault: true
        ))
    }
}
