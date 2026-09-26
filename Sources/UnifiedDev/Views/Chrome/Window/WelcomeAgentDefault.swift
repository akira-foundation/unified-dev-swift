import Core
import Observation

@MainActor
@Observable
final class WelcomeAgentDefault {
    private(set) var selected: AgentKind?
    private(set) var failure: String?

    @ObservationIgnored private let store: () async -> Store?
    @ObservationIgnored private var writing: Task<Void, Never>?
    @ObservationIgnored private var generation = 0

    init(store: @escaping () async -> Store?) {
        self.store = store
    }

    func load() {
        guard selected == nil else { return }
        let mine = generation
        Task {
            guard let store = await store() else { return }
            let defaults = await AppDefaults.load(from: store)
            guard generation == mine, selected == nil else { return }
            selected = defaults.backend
        }
    }

    func cancel() {
        generation += 1
        writing?.cancel()
        writing = nil
    }

    func choose(_ kind: AgentKind) {
        generation += 1
        let mine = generation
        selected = kind
        failure = nil
        writing?.cancel()
        writing = Task { await write(kind, generation: mine) }
    }

    private func write(_ kind: AgentKind, generation mine: Int) async {
        guard let store = await store(), generation == mine else { return }
        let catalog = ComposerModelCatalog.shared
        await waitForModels(of: kind, in: catalog, generation: mine)
        guard generation == mine else { return }

        let current = await AppDefaults.load(from: store)
        guard generation == mine else { return }
        guard let next = OnboardingAgentChoice.defaults(
            choosing: kind, from: current, models: catalog.models
        ) else {
            failure = "Unified Dev could not read \(kind.label)'s models, so it kept the agent as it was."
            selected = current.backend
            return
        }
        do {
            try await next.saveChanges(from: current, to: store)
        } catch {
            guard generation == mine else { return }
            failure = error.readableMessage
            selected = current.backend
        }
    }

    private func waitForModels(
        of kind: AgentKind,
        in catalog: ComposerModelCatalog,
        generation mine: Int
    ) async {
        guard OnboardingAgentChoice.needsModelList(for: kind), (catalog.models[kind] ?? []).isEmpty
        else { return }
        catalog.load()
        let deadline = ContinuousClock.now + .seconds(30)
        while (catalog.models[kind] ?? []).isEmpty, catalog.lastFailure == nil,
              ContinuousClock.now < deadline, generation == mine {
            try? await Task.sleep(for: .milliseconds(200))
        }
    }
}
