import SwiftUI
import Core

struct ComposerModelSection: Identifiable, Equatable {
    var kind: AgentKind
    var options: [ComposerOption]

    var id: String { kind.rawValue }
    var title: String { kind.label }
}

@MainActor
@Observable
final class ComposerModelCatalog {
    static let shared = ComposerModelCatalog()

    private(set) var models: [AgentKind: [AgentModel]] = [:]
    private(set) var isLoading = false
    private(set) var failures: [AgentKind: ModelListFailure] = [:]
    private(set) var observedClaudeModels: [String: String] = [:]

    private var sources: [AgentKind: AgentModelSource]
    private var accounts: [AgentKind: AgentAccountHome] = [:]
    private var accountsAreKnown = false
    private var loadTask: Task<Void, Never>?
    private var loadGeneration = UUID()
    private var observationTask: Task<Void, Never>?

    init(sources: [AgentKind: AgentModelSource] = AgentModelSource.live()) {
        self.sources = sources
    }

    func configure(store: Store) {
        Task { await ComposerPlanningSupport.shared.refresh(from: store) }
        sources = AgentModelSource.live(store: store, accounts: accounts)
        guard accountsAreKnown else { return }
        followClaudeObservations(in: store)
        refresh()
    }

    func adopt(accounts adopted: [AgentKind: AgentAccountHome], store: Store) {
        guard adopted != accounts || !accountsAreKnown else { return }
        accountsAreKnown = true
        accounts = adopted
        sources = AgentModelSource.live(store: store, accounts: adopted)
        followClaudeObservations(in: store)
        refresh()
    }

    private func followClaudeObservations(in store: Store) {
        observationTask?.cancel()
        let account = accounts[.claudeCode]
        observationTask = Task { [weak self] in
            var changes = store.changes(of: [.settings]).makeAsyncIterator()
            repeat {
                self?.adoptClaudeObservations(await ClaudeResolvedModel.observed(account: account, in: store))
            } while await changes.next() != nil
        }
    }

    private func adoptClaudeObservations(_ observed: [String: String]) {
        guard !Task.isCancelled, observed != observedClaudeModels else { return }
        observedClaudeModels = observed
    }

    func load() {
        guard accountsAreKnown, loadTask == nil else { return }
        let needed = AgentModelSource.kindsAwaitingModels(sources: sources, loaded: models)
        guard !needed.isEmpty else { return }
        isLoading = true
        let generation = loadGeneration
        loadTask = Task { [sources] in
            var collected: [AgentKind: ModelListFailure] = [:]
            for kind in needed {
                guard generation == self.loadGeneration else { return }
                guard let source = sources[kind] else { continue }
                do {
                    let fetched = try await source.models()
                    guard generation == self.loadGeneration else { return }
                    self.models[kind] = fetched
                } catch {
                    collected[kind] = await source.failure(of: kind, because: error)
                }
            }
            guard generation == self.loadGeneration else { return }
            self.failures = collected
            self.isLoading = false
            self.loadTask = nil
        }
    }

    func refresh() {
        loadTask?.cancel()
        loadGeneration = UUID()
        let generation = loadGeneration
        models = [:]
        failures = [:]
        isLoading = true
        loadTask = Task { [sources] in
            for source in sources.values { await source.invalidate() }
            guard generation == self.loadGeneration else { return }
            self.loadTask = nil
            self.isLoading = false
            load()
        }
    }

    func hasGivenUp(on kind: AgentKind) -> Bool {
        ModelListFailure.hasGivenUp(on: kind, among: failures, isLoading: isLoading)
    }

    func sections(includingCurrent current: String, on kind: AgentKind) -> [ComposerModelSection] {
        let owner = backend(ofModel: current, current: kind)
        return AgentKind.allCases.filter(\.canRunWorkspaces).compactMap { backend in
            let options = self.options(for: backend, including: backend == owner ? current : "")
            guard !options.isEmpty else { return nil }
            return ComposerModelSection(kind: backend, options: options)
        }
    }

    func options(for kind: AgentKind, including current: String = "") -> [ComposerOption] {
        let known = (models[kind] ?? []).filter { !$0.hidden }
        if kind == .claudeCode {
            return ComposerOption.options(
                ClaudeModelCatalog.offered(read: known, including: current, observed: observedClaudeModels)
            )
        }
        let options = ComposerOption.options(known)
        return current.isEmpty ? options : ComposerOption.adding([current], to: options)
    }

    func backend(ofModel id: String, current: AgentKind) -> AgentKind {
        DefaultBackend.kind(
            ofModel: id,
            running: current,
            models: models
        )
    }

    func efforts(for kind: AgentKind, model: String, offeringAgentDefault: Bool) -> [ComposerOption] {
        let announced = kind.announcesModelEfforts ? models[kind]?.first { $0.id == model } : nil
        let supported = announced?.supportedEfforts
            ?? ComposerOption.efforts.map { AgentModelEffort(id: $0.id, label: $0.label) }
        return ComposerEffort.choices(supported, offeringUnset: offeringAgentDefault).map {
            ComposerOption(id: $0.id, label: $0.label)
        }
    }

    func resolvedEffort(_ wanted: String, for kind: AgentKind, model: String) -> String {
        DefaultBackend.effort(
            wanted,
            on: kind,
            model: model,
            models: models
        )
    }
}
