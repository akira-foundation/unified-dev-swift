import Foundation
import Observation
import Core

@MainActor
@Observable
final class ComposerPlanningSupport {
    static let shared = ComposerPlanningSupport()
    private(set) var isAvailable = true
    private(set) var isChecking = false
    @ObservationIgnored private var store: Store?
    @ObservationIgnored private var revision = 0

    func refresh(from store: Store) async {
        self.store = store
        guard !isChecking else { return }
        let revision = self.revision
        do {
            let available = try await store.setting(CodexPlanningCapability.unavailableKey) != "1"
            guard revision == self.revision, !isChecking else { return }
            if isAvailable != available { isAvailable = available }
        } catch {
            return
        }
    }

    func checkAgain() async {
        guard let store, !isChecking else { return }
        isChecking = true
        revision += 1
        defer { isChecking = false }
        do {
            try await store.setSetting(CodexPlanningCapability.rescanKey, UUID().uuidString)
            try await store.setSetting(CodexPlanningCapability.unavailableKey, nil)
            isAvailable = true
        } catch { isAvailable = false }
    }
}
