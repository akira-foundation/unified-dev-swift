import Foundation
import Core

@MainActor
enum PreviewScenarioLaunch {
    private static var request: Result<(scenario: PreviewScenario, root: String), Error>?

    static func prepare() {
        guard let path = PreviewLaunch.scenarioPath() else { return }
        do {
            let root = try PreviewLaunch.root()
            let scenario = try PreviewScenario.read(path: path)
            if !scenario.welcome {
                UserDefaults.standard.set(true, forKey: OnboardingGate.completedKey)
            }
            request = .success((scenario, root))
        } catch {
            request = .failure(error)
        }
    }

    static func seed(with manager: WorkspaceManager) async -> AppAlert? {
        guard let request else { return nil }
        Self.request = nil
        do {
            let (scenario, root) = try request.get()
            let seeder = PreviewScenarioSeeder(manager: manager, scratchRoot: PreviewIdentity.scratch(in: root))
            let outcome = try await seeder.seed(scenario)
            Log.launch.info("""
                seeded the preview scenario: \(outcome.projects, privacy: .public) projects, \
                \(outcome.workspaces, privacy: .public) workspaces, \(outcome.chats, privacy: .public) chats
                """)
            return nil
        } catch PreviewScenarioError.alreadySeeded {
            Log.launch.info("the preview already holds projects, so the scenario was left alone")
            return nil
        } catch {
            return AppAlert(title: "Could not set up the preview scenario", message: String(describing: error))
        }
    }
}
