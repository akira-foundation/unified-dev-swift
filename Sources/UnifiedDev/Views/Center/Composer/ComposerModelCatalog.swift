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
    private(set) var lastFailure: String?

    private var sources: [AgentKind: AgentModelSource]
    private var accounts: [AgentKind: AgentAccountHome] = [:]
    private var accountsAreKnown = false
    private var loadTask: Task<Void, Never>?
    private var loadGeneration = UUID()

    init(sources: [AgentKind: AgentModelSource] = AgentModelSource.live()) {
        self.sources = sources
    }

    func configure(store: Store) {
        Task { await ComposerPlanningSupport.shared.refresh(from: store) }
        sources = AgentModelSource.live(store: store, accounts: accounts)
        guard accountsAreKnown else { return }
        refresh()
    }

    func adopt(accounts adopted: [AgentKind: AgentAccountHome], store: Store) {
        guard adopted != accounts || !accountsAreKnown else { return }
        accountsAreKnown = true
        accounts = adopted
        sources = AgentModelSource.live(store: store, accounts: adopted)
        refresh()
    }

    func load() {
        guard accountsAreKnown, loadTask == nil else { return }
        let needed = AgentModelSource.kindsAwaitingModels(sources: sources, loaded: models)
        guard !needed.isEmpty else { return }
        lastFailure = nil
        isLoading = true
        let generation = loadGeneration
        loadTask = Task { [sources] in
            var failure: String?
            for kind in needed {
                guard generation == self.loadGeneration else { return }
                guard let source = sources[kind] else { continue }
                do {
                    let fetched = try await source.models()
                    guard generation == self.loadGeneration else { return }
                    self.models[kind] = fetched
                } catch {
                    if failure == nil { failure = error.readableMessage }
                }
            }
            guard generation == self.loadGeneration else { return }
            self.lastFailure = failure
            self.isLoading = false
            self.loadTask = nil
        }
    }

    func refresh() {
        loadTask?.cancel()
        loadGeneration = UUID()
        let generation = loadGeneration
        models = [:]
        lastFailure = nil
        isLoading = true
        loadTask = Task { [sources] in
            for source in sources.values { await source.invalidate() }
            guard generation == self.loadGeneration else { return }
            self.loadTask = nil
            self.isLoading = false
            load()
        }
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
                ClaudeModelCatalog.offered(read: known, including: current)
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

    func efforts(for kind: AgentKind, model: String) -> [ComposerOption] {
        guard kind != .claudeCode, let found = models[kind]?.first(where: { $0.id == model }) else {
            return ComposerOption.efforts
        }
        return found.supportedEfforts.map { ComposerOption(id: $0.id, label: $0.label) }
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
