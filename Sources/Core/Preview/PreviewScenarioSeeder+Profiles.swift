import Foundation

extension PreviewScenarioSeeder {
    static let initialKey = PreviewScenario.initialProfileName.lowercased()

    func seedProfiles(_ scenario: PreviewScenario) async throws -> [String: ProfileID] {
        var ids = [Self.initialKey: ProfileID.initial]
        for profile in scenario.profiles {
            let created = try await manager.store.createProfile(
                name: profile.name, colour: profile.colour, symbol: profile.symbol,
                occupiedFolders: ProfileFolder.occupied(under: manager.workspacesRoot)
            )
            ids[profile.name.lowercased()] = created.id
        }
        return ids
    }
}
