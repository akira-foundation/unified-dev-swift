import Foundation

extension PreviewScenarioSeeder {
    func seedRecentFolders(_ scenario: PreviewScenario) async throws -> Int {
        var seeded = 0
        for name in scenario.recentFolders.reversed() {
            guard let path = folder(named: name, in: scenario) else { continue }
            try await DirectoryPreferences.remember(path, in: manager.store)
            seeded += 1
        }
        return seeded
    }

    private func folder(named name: String, in scenario: PreviewScenario) -> String? {
        guard !scenario.projects.contains(where: { $0.name == name }) else {
            return projectsRoot + "/" + name
        }
        let loose = scenario.looseRepositories + scenario.looseFolders
        guard loose.contains(name) else { return nil }
        return looseRoot + "/" + name
    }
}
