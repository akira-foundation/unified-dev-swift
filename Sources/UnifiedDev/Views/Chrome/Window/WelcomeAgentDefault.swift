import Core
import Observation

@MainActor
@Observable
final class WelcomeAgentDefault {
    private(set) var selected: AgentKind?

    @ObservationIgnored private let store: () async -> Store?
    @ObservationIgnored private var writing: Task<Void, Never>?

    init(store: @escaping () async -> Store?) {
        self.store = store
    }

    func load() {
        guard selected == nil else { return }
        Task {
            guard let store = await store() else { return }
            let defaults = await AppDefaults.load(from: store)
            if selected == nil { selected = defaults.backend }
        }
    }

    func choose(_ kind: AgentKind) {
        selected = kind
        writing?.cancel()
        writing = Task {
            guard let store = await store() else { return }
            let catalog = ComposerModelCatalog.shared
            if kind != .claudeCode, (catalog.models[kind] ?? []).isEmpty {
                catalog.load()
                let deadline = ContinuousClock.now + .seconds(30)
                while (catalog.models[kind] ?? []).isEmpty, catalog.isLoading, ContinuousClock.now < deadline {
                    try? await Task.sleep(for: .milliseconds(200))
                    if Task.isCancelled { return }
                }
            }
            guard !Task.isCancelled else { return }
            let current = await AppDefaults.load(from: store)
            guard let next = OnboardingAgentChoice.defaults(
                choosing: kind, from: current, models: catalog.models[kind] ?? []
            ) else {
                selected = current.backend
                return
            }
            try? await next.saveChanges(from: current, to: store)
        }
    }
}
